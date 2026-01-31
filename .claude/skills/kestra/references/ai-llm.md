# AI & LLM Plugin Reference

Build AI workflows with OpenAI, Anthropic, Google Gemini, and other LLM providers.

## Table of Contents
1. [Providers](#providers)
2. [ChatCompletion](#chatcompletion)
3. [OpenAI Plugin](#openai-plugin)
4. [AI Agents](#ai-agents)
5. [JSON Structured Extraction](#json-structured-extraction)
6. [Classification](#classification)
7. [RAG (Retrieval Augmented Generation)](#rag)
8. [Tools & Content Retrievers](#tools-and-content-retrievers)
9. [Memory](#memory)

## Providers

The AI plugin supports multiple LLM providers:

| Provider | Type |
|----------|------|
| OpenAI | `io.kestra.plugin.ai.provider.OpenAI` |
| Anthropic | `io.kestra.plugin.ai.provider.Anthropic` |
| Google Gemini | `io.kestra.plugin.ai.provider.GoogleGemini` |
| Google Vertex AI | `io.kestra.plugin.ai.provider.GoogleVertexAI` |
| Azure OpenAI | `io.kestra.plugin.ai.provider.AzureOpenAI` |
| Amazon Bedrock | `io.kestra.plugin.ai.provider.AmazonBedrock` |
| Mistral AI | `io.kestra.plugin.ai.provider.MistralAI` |
| DeepSeek | `io.kestra.plugin.ai.provider.DeepSeek` |
| Ollama | `io.kestra.plugin.ai.provider.Ollama` |

### Provider Configuration
```yaml
provider:
  type: io.kestra.plugin.ai.provider.OpenAI
  apiKey: "{{ secret('OPENAI_API_KEY') }}"
  modelName: gpt-4o
```

## ChatCompletion

Generic chat interface for LLMs.

### Basic Chat
```yaml
- id: chat
  type: io.kestra.plugin.ai.completion.ChatCompletion
  provider:
    type: io.kestra.plugin.ai.provider.GoogleGemini
    apiKey: "{{ kv('GEMINI_API_KEY') }}"
    modelName: gemini-2.5-flash
  messages:
    - type: SYSTEM
      content: You are a helpful assistant.
    - type: USER
      content: "{{ inputs.prompt }}"
```

### With JSON Schema Output
```yaml
- id: structured_chat
  type: io.kestra.plugin.ai.completion.ChatCompletion
  provider:
    type: io.kestra.plugin.ai.provider.GoogleGemini
    apiKey: "{{ kv('GEMINI_API_KEY') }}"
    modelName: gemini-2.5-flash
  configuration:
    responseFormat:
      type: JSON
      jsonSchema:
        type: object
        required: ["name", "city"]
        properties:
          name:
            type: string
          city:
            type: string
  messages:
    - type: USER
      content: "Extract name and city from: John lives in Paris"
```

### Accessing Output
```yaml
- id: use_response
  type: io.kestra.plugin.core.log.Log
  message: "{{ outputs.chat.response }}"
```

## OpenAI Plugin

Dedicated OpenAI integration.

### ChatCompletion
```yaml
- id: openai_chat
  type: io.kestra.plugin.openai.ChatCompletion
  apiKey: "{{ secret('OPENAI_API_KEY') }}"
  model: gpt-4o
  prompt: "What is data orchestration?"
```

### With Messages
```yaml
- id: openai_messages
  type: io.kestra.plugin.openai.ChatCompletion
  apiKey: "{{ secret('OPENAI_API_KEY') }}"
  model: gpt-4o
  messages:
    - role: system
      content: You are a helpful data engineer.
    - role: user
      content: "{{ inputs.question }}"
```

### Function Calling
```yaml
- id: function_call
  type: io.kestra.plugin.openai.ChatCompletion
  apiKey: "{{ secret('OPENAI_API_KEY') }}"
  model: gpt-4o
  messages:
    - role: user
      content: "{{ inputs.review }}"
  functions:
    - name: classify_review
      description: Classify customer review sentiment and urgency
      parameters:
        - name: sentiment
          type: string
          description: The sentiment of the review
          enumValues: [positive, negative, neutral]
          required: true
        - name: urgency
          type: string
          description: How urgently to respond
          enumValues: [immediate, normal, low]
          required: true
```

### Image Generation
```yaml
- id: generate_image
  type: io.kestra.plugin.openai.ImageGeneration
  apiKey: "{{ secret('OPENAI_API_KEY') }}"
  prompt: "A futuristic data center with glowing servers"
  model: dall-e-3
  size: "1024x1024"
```

## AI Agents

Autonomous AI systems that can use tools, memory, and make decisions.

### Basic Agent
```yaml
- id: agent
  type: io.kestra.plugin.ai.agent.AIAgent
  provider:
    type: io.kestra.plugin.ai.provider.OpenAI
    apiKey: "{{ kv('OPENAI_API_KEY') }}"
    modelName: gpt-4o
  systemMessage: |
    You are a helpful data analysis assistant.
    Be concise and accurate.
  prompt: "{{ inputs.question }}"
```

### Agent with Tools
```yaml
- id: agent_with_tools
  type: io.kestra.plugin.ai.agent.AIAgent
  provider:
    type: io.kestra.plugin.ai.provider.OpenAI
    apiKey: "{{ kv('OPENAI_API_KEY') }}"
    modelName: gpt-4o
  systemMessage: |
    You are a research assistant. Use web search to find current information.
  prompt: "{{ inputs.prompt }}"
  tools:
    - type: io.kestra.plugin.ai.tool.GoogleCustomWebSearch
      apiKey: "{{ kv('GOOGLE_SEARCH_API_KEY') }}"
      csi: "{{ kv('GOOGLE_SEARCH_CSI') }}"
```

### Agent Triggering Kestra Flows
```yaml
- id: ops_agent
  type: io.kestra.plugin.ai.agent.AIAgent
  provider:
    type: io.kestra.plugin.ai.provider.OpenAI
    apiKey: "{{ kv('OPENAI_API_KEY') }}"
    modelName: gpt-4o
  systemMessage: |
    You are an incident triage agent.
    Use the kestra_flow tool to trigger appropriate remediation flows.
  prompt: |
    Incident: {{ inputs.incident }}
    Available flows in "prod.ops" namespace:
    - restart-service (inputs: service, reason)
    - run-backfill (inputs: service, hours)
    - notify-oncall (inputs: team, severity, message)
  tools:
    - type: io.kestra.plugin.ai.tool.KestraFlow
```

### Agent with Memory
```yaml
- id: chat_agent
  type: io.kestra.plugin.ai.agent.AIAgent
  provider:
    type: io.kestra.plugin.ai.provider.OpenAI
    apiKey: "{{ kv('OPENAI_API_KEY') }}"
    modelName: gpt-4o
  prompt: "{{ inputs.message }}"
  memory:
    type: io.kestra.plugin.ai.memory.KestraKVStore
    memoryId: "{{ inputs.session_id }}"
    ttl: PT1H
    messages: 10  # Keep last 10 messages
```

## JSON Structured Extraction

Extract structured data from unstructured text.

```yaml
- id: extract_order
  type: io.kestra.plugin.ai.completion.JSONStructuredExtraction
  provider:
    type: io.kestra.plugin.ai.provider.OpenAI
    apiKey: "{{ kv('OPENAI_API_KEY') }}"
    modelName: gpt-4o
  schemaName: Order
  jsonFields:
    - order_id
    - customer_name
    - shipping_city
    - total_amount
  prompt: |
    Extract order details from:
    "Order #A-1043 for Jane Doe, shipped to Berlin. Total: 249.99 EUR."
```

**Output:** `{{ outputs.extract_order.json }}`

## Classification

Classify text into predefined categories.

```yaml
- id: classify_ticket
  type: io.kestra.plugin.ai.completion.Classification
  provider:
    type: io.kestra.plugin.ai.provider.GoogleGemini
    apiKey: "{{ kv('GEMINI_API_KEY') }}"
    modelName: gemini-2.5-flash
  categories:
    - BILLING
    - TECHNICAL
    - ACCOUNT
    - GENERAL
  prompt: "{{ inputs.ticket_text }}"
```

**Output:** `{{ outputs.classify_ticket.category }}`

## RAG

Retrieval Augmented Generation for grounded responses.

### Ingest Documents
```yaml
- id: ingest
  type: io.kestra.plugin.ai.rag.IngestDocument
  provider:
    type: io.kestra.plugin.ai.provider.GoogleGemini
    modelName: gemini-embedding-exp-03-07
    apiKey: "{{ kv('GEMINI_API_KEY') }}"
  embeddings:
    type: io.kestra.plugin.ai.embeddings.KestraKVStore
    drop: true  # Clear existing embeddings
  fromExternalURLs:
    - "https://example.com/docs/guide.md"
    - "https://example.com/docs/api.md"
```

### RAG Chat
```yaml
- id: rag_chat
  type: io.kestra.plugin.ai.rag.ChatCompletion
  chatProvider:
    type: io.kestra.plugin.ai.provider.GoogleGemini
    apiKey: "{{ kv('GEMINI_API_KEY') }}"
    modelName: gemini-2.5-flash
  embeddingProvider:
    type: io.kestra.plugin.ai.provider.GoogleGemini
    modelName: gemini-embedding-exp-03-07
  embeddings:
    type: io.kestra.plugin.ai.embeddings.KestraKVStore
  systemMessage: Answer based only on the provided context.
  prompt: "{{ inputs.question }}"
```

### RAG with Web Search Retriever
```yaml
- id: rag_websearch
  type: io.kestra.plugin.ai.rag.ChatCompletion
  chatProvider:
    type: io.kestra.plugin.ai.provider.GoogleGemini
    apiKey: "{{ kv('GEMINI_API_KEY') }}"
    modelName: gemini-2.5-flash
  contentRetrievers:
    - type: io.kestra.plugin.ai.retriever.TavilyWebSearch
      apiKey: "{{ kv('TAVILY_API_KEY') }}"
  systemMessage: You are a helpful assistant.
  prompt: "What is the latest Kestra release?"
```

## Tools and Content Retrievers

### Available Tools
| Tool | Type | Description |
|------|------|-------------|
| Web Search (Google) | `io.kestra.plugin.ai.tool.GoogleCustomWebSearch` | Search the web |
| Web Search (Tavily) | `io.kestra.plugin.ai.tool.TavilyWebSearch` | AI-optimized search |
| Kestra Flow | `io.kestra.plugin.ai.tool.KestraFlow` | Trigger Kestra flows |
| MCP Client | `io.kestra.plugin.ai.tool.DockerMcpClient` | Model Context Protocol |

### Tools vs Content Retrievers
- **Tools**: Called only when LLM decides to use them
- **Content Retrievers**: Always called to provide context

```yaml
# Tool (called on demand)
tools:
  - type: io.kestra.plugin.ai.tool.GoogleCustomWebSearch
    apiKey: "{{ kv('GOOGLE_SEARCH_API_KEY') }}"

# Content Retriever (always called)
contentRetrievers:
  - type: io.kestra.plugin.ai.retriever.TavilyWebSearch
    apiKey: "{{ kv('TAVILY_API_KEY') }}"
```

## Memory

Persistent conversation memory.

### KV Store Memory
```yaml
memory:
  type: io.kestra.plugin.ai.memory.KestraKVStore
  memoryId: "conversation_{{ inputs.user_id }}"
  ttl: PT24H  # Time to live
  messages: 20  # Max messages to retain
```

## Plugin Defaults for AI

```yaml
pluginDefaults:
  - type: io.kestra.plugin.ai.provider.OpenAI
    values:
      apiKey: "{{ secret('OPENAI_API_KEY') }}"
      modelName: gpt-4o
  
  - type: io.kestra.plugin.ai.provider.GoogleGemini
    values:
      apiKey: "{{ kv('GEMINI_API_KEY') }}"
      modelName: gemini-2.5-flash
```

## Complete Example: AI Data Pipeline

```yaml
id: ai_data_pipeline
namespace: company.ai
description: Extract, classify, and process data with AI

inputs:
  - id: document_url
    type: STRING

tasks:
  - id: download
    type: io.kestra.plugin.core.http.Download
    uri: "{{ inputs.document_url }}"

  - id: extract_entities
    type: io.kestra.plugin.ai.completion.JSONStructuredExtraction
    provider:
      type: io.kestra.plugin.ai.provider.OpenAI
      apiKey: "{{ secret('OPENAI_API_KEY') }}"
      modelName: gpt-4o
    schemaName: Entities
    jsonFields: [companies, people, locations, dates]
    prompt: |
      Extract all entities from this document:
      {{ read(outputs.download.uri) }}

  - id: classify_document
    type: io.kestra.plugin.ai.completion.Classification
    provider:
      type: io.kestra.plugin.ai.provider.OpenAI
      apiKey: "{{ secret('OPENAI_API_KEY') }}"
      modelName: gpt-4o
    categories: [LEGAL, FINANCIAL, TECHNICAL, MARKETING]
    prompt: "{{ read(outputs.download.uri) }}"

  - id: store_results
    type: io.kestra.plugin.scripts.python.Script
    containerImage: python:slim
    script: |
      from kestra import Kestra
      
      results = {
        "entities": {{ outputs.extract_entities.json }},
        "category": "{{ outputs.classify_document.category }}"
      }
      Kestra.outputs(results)
```
