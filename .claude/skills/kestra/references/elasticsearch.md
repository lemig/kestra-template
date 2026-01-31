# Elasticsearch Plugin Reference

Connect Elasticsearch search and analytics engine to Kestra workflows.

## Table of Contents
1. [Connection Configuration](#connection-configuration)
2. [Search](#search)
3. [Get Document](#get-document)
4. [Put Document](#put-document)
5. [Bulk Load](#bulk-load)
6. [ES|QL Query](#esql-query)
7. [Generic Request](#generic-request)
8. [Scroll](#scroll)

## Connection Configuration

All Elasticsearch tasks use a common `connection` property:

```yaml
connection:
  hosts:
    - "http://localhost:9200"
    - "http://elasticsearch-node2:9200"
  basicAuth:
    username: elastic
    password: "{{ secret('ES_PASSWORD') }}"
  # Optional settings
  trustAllSsl: false  # For self-signed certs
  pathPrefix: "/elasticsearch"  # If behind proxy
  headers:
    - "Authorization: ApiKey yourEncodedApiKey"
```

## Search

Query documents and retrieve results.

```yaml
- id: search
  type: io.kestra.plugin.elasticsearch.Search
  connection:
    hosts:
      - "http://localhost:9200"
  indexes:
    - "my_index"
  fetchType: FETCH  # FETCH_ONE, FETCH, STORE, NONE
  request:
    query:
      bool:
        must:
          - match:
              title: "{{ inputs.search_term }}"
        filter:
          - term:
              status: published
    size: 100
    sort:
      - created_at: desc
```

### Fetch Types
| Type | Description | Output |
|------|-------------|--------|
| `FETCH_ONE` | Single document | `outputs.search.row` |
| `FETCH` | All documents as list | `outputs.search.rows` |
| `STORE` | Save to internal storage | `outputs.search.uri` |
| `NONE` | No output (count only) | `outputs.search.size` |

### Accessing Results
```yaml
- id: process_results
  type: io.kestra.plugin.core.log.Log
  message: |
    Found {{ outputs.search.size }} documents
    First result: {{ outputs.search.rows[0].title }}
```

## Get Document

Retrieve a single document by ID.

```yaml
- id: get_doc
  type: io.kestra.plugin.elasticsearch.Get
  connection:
    hosts:
      - "http://localhost:9200"
  index: "my_index"
  key: "document_id_123"
```

**Output:** `{{ outputs.get_doc.row }}`

## Put Document

Insert or update a document.

```yaml
- id: put_doc
  type: io.kestra.plugin.elasticsearch.Put
  connection:
    hosts:
      - "http://localhost:9200"
  index: "my_index"
  key: "{{ inputs.doc_id }}"
  value:
    name: "{{ inputs.name }}"
    email: "{{ inputs.email }}"
    created_at: "{{ now() }}"
```

### From JSON String
```yaml
- id: put_json
  type: io.kestra.plugin.elasticsearch.Put
  connection:
    hosts:
      - "http://localhost:9200"
  index: "my_index"
  key: "{{ inputs.doc_id }}"
  value: "{{ outputs.api.body }}"  # JSON string
```

## Bulk Load

Load documents in bulk from internal storage.

```yaml
- id: load_bulk
  type: io.kestra.plugin.elasticsearch.Load
  connection:
    hosts:
      - "http://localhost:9200"
  from: "{{ outputs.extract.uri }}"  # Ion/JSON file
  index: "my_index"
  chunk: 1000  # Documents per bulk request
  idKey: "id"  # Use this field as document ID
  removeIdKey: true  # Remove id field from document
```

### Alternative: Bulk Task
```yaml
- id: bulk
  type: io.kestra.plugin.elasticsearch.Bulk
  connection:
    hosts:
      - "http://localhost:9200"
  from: "{{ outputs.download.uri }}"
```

## ES|QL Query

Query using Elasticsearch Query Language (ES|QL).

```yaml
- id: esql_query
  type: io.kestra.plugin.elasticsearch.Esql
  connection:
    hosts:
      - "https://cluster.es.io:443"
    headers:
      - "Authorization: ApiKey yourApiKey"
  fetchType: STORE
  query: |
    FROM books
    | KEEP author, name, page_count, release_date
    | WHERE page_count > 200
    | SORT page_count DESC
    | LIMIT 10
```

## Generic Request

Send any Elasticsearch REST API request.

### POST (Insert)
```yaml
- id: insert
  type: io.kestra.plugin.elasticsearch.Request
  connection:
    hosts:
      - "http://localhost:9200"
  method: "POST"
  endpoint: "my_index/_doc/my_id"
  body:
    name: "John Doe"
    email: "john@example.com"
```

### GET (Search)
```yaml
- id: search_request
  type: io.kestra.plugin.elasticsearch.Request
  connection:
    hosts:
      - "http://localhost:9200"
  method: "GET"
  endpoint: "my_index/_search"
  parameters:
    q: "name:John"
```

### DELETE
```yaml
- id: delete_doc
  type: io.kestra.plugin.elasticsearch.Request
  connection:
    hosts:
      - "http://localhost:9200"
  method: "DELETE"
  endpoint: "my_index/_doc/my_id"
```

## Scroll

Retrieve large result sets using scroll API.

```yaml
- id: scroll_all
  type: io.kestra.plugin.elasticsearch.Scroll
  connection:
    hosts:
      - "http://localhost:9200"
  indexes:
    - "large_index"
  fetchType: STORE
  request:
    query:
      match_all: {}
    size: 1000  # Per scroll batch
```

## Complete Example: RAG with Elasticsearch

```yaml
id: elasticsearch_rag
namespace: company.ai
description: Search Elasticsearch and generate AI response

inputs:
  - id: question
    type: STRING
    required: true

tasks:
  - id: search
    type: io.kestra.plugin.elasticsearch.Search
    connection:
      hosts:
        - "http://localhost:9200"
    indexes:
      - "knowledge_base"
    request:
      size: 5
      query:
        multi_match:
          query: "{{ inputs.question }}"
          fields: ["title", "content"]
          type: best_fields

  - id: build_context
    type: io.kestra.plugin.core.debug.Return
    format: |
      {% for doc in outputs.search.rows %}
      Title: {{ doc.title }}
      Content: {{ doc.content }}
      ---
      {% endfor %}

  - id: generate_response
    type: io.kestra.plugin.openai.ChatCompletion
    apiKey: "{{ secret('OPENAI_API_KEY') }}"
    model: gpt-4o
    prompt: |
      Based on the following context, answer the question.
      
      Context:
      {{ outputs.build_context.value }}
      
      Question: {{ inputs.question }}
```

## Plugin Defaults for Elasticsearch

```yaml
pluginDefaults:
  - type: io.kestra.plugin.elasticsearch
    values:
      connection:
        hosts:
          - "{{ secret('ES_HOST') }}"
        basicAuth:
          username: elastic
          password: "{{ secret('ES_PASSWORD') }}"
```
