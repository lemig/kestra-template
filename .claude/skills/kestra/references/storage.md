# Internal Storage & File Access Reference

How Kestra stores, references, and passes files between tasks.

## Table of Contents
1. [Overview](#overview)
2. [URI Schemes](#uri-schemes)
3. [fetchType Modes](#fetchtype-modes)
4. [Ion Format](#ion-format)
5. [read() Function](#read-function)
6. [inputFiles & outputFiles](#inputfiles--outputfiles)
7. [Storage Management Tasks](#storage-management-tasks)
8. [Storage Backends](#storage-backends)
9. [Execution Context vs Internal Storage](#execution-context-vs-internal-storage)
10. [Important Limitations](#important-limitations)

---

## Overview

Internal Storage is Kestra's dedicated file storage for handling arbitrary-sized files during executions. It stores inputs, outputs, and artifacts and is used to pass data between tasks.

- **Database** stores: flows, metadata, logs, secrets
- **Internal Storage** stores: inputs, outputs, files, KV store data

Data stored in internal storage is referenced via URI and accessed through Pebble expressions:
```yaml
{{ outputs.task_id.uri }}
{{ outputs.task_id.outputFiles['filename.csv'] }}
```

## URI Schemes

Kestra supports three file URI schemes (collectively called "Smart URI"):

### `kestra:///` — Internal Storage
References files in Kestra's internal storage. Three slashes.

```yaml
# Typical internal storage URI structure:
kestra:///<namespace>/<flow-id-kebab>/executions/<exec-id>/tasks/<task-id-kebab>/<taskrun-id>/<filename>

# Example:
kestra:///orbis/batch-match/executions/4EDUM2VpFfgdGeWzNz4TZS/tasks/load-local-file/72jxjY9uOOHNRbN0YocOHJ/csv_input.csv
```

### `nsfile:///` — Namespace Files
References files stored in the namespace's `_files/` directory. Three slashes for current namespace.

```yaml
# Current namespace (three slashes):
inputFiles:
  hello.py: nsfile:///scripts/hello.py

# Cross-namespace (two slashes):
inputFiles:
  hello.py: nsfile://other.namespace/scripts/hello.py
```

### `file:///` — Local Filesystem
References files on the host machine. Requires allowed-paths configuration.

```yaml
# Kestra configuration required:
kestra:
  local-files:
    allowed-paths:
      - /data
      - /scripts

# Usage in flows:
inputFiles:
  data.csv: file:///data/input.csv
```

## fetchType Modes

Many tasks (database queries, API calls, etc.) support a `fetchType` property that controls how results are returned:

| fetchType | Returns | Access | Best For |
|-----------|---------|--------|----------|
| `FETCH_ONE` | Single row in execution context | `outputs.task.row` | Single record lookups |
| `FETCH` | All rows in execution context | `outputs.task.rows` | Small result sets (<1MB) |
| `STORE` | URI to internal storage file | `outputs.task.uri` | Large datasets |
| `NONE` | Only count | `outputs.task.size` | Counting records |

```yaml
- id: query
  type: io.kestra.plugin.aws.dynamodb.Query
  tableName: persons
  keyConditionExpression: id = :id
  expressionAttributeValues:
    :id: "1"
  fetchType: STORE  # Returns outputs.query.uri
```

## Ion Format

Internal storage uses **Amazon Ion** format by default — a superset of JSON that supports typed values. Ion is the format used for data passing between tasks.

Convert to/from other formats using the **Serdes plugin**:

```yaml
# Ion → CSV
- id: to_csv
  type: io.kestra.plugin.serdes.csv.IonToCsv
  from: "{{ outputs.query.uri }}"

# CSV → Ion
- id: to_ion
  type: io.kestra.plugin.serdes.csv.CsvToIon
  from: "{{ outputs.to_csv.uri }}"
  header: true

# Ion → JSON
- id: to_json
  type: io.kestra.plugin.serdes.json.IonToJson
  from: "{{ outputs.query.uri }}"

# JSON → Ion
- id: to_ion
  type: io.kestra.plugin.serdes.json.JsonToIon
  from: "{{ outputs.download.uri }}"
```

Available Serdes formats: **CSV, JSON, Avro, XML, Parquet**.

## read() Function

Reads file content as a string in Pebble expressions. Works with all URI schemes.

```yaml
# Read a FILE-type input:
{{ read(inputs.file) }}

# Read a task output URI:
{{ read(outputs.mytaskid.uri) }}

# Read a trigger URI:
{{ read(trigger.uri) }}

# Read a namespace file:
{{ read('scripts/hello.py') }}

# Read with nsfile:// protocol:
{{ read('nsfile:///query.sql') }}
```

### Combining read() with JSON processing:
```yaml
# Parse file content as JSON and extract with jq:
{{ json(read(outputs.extract.uri)) | jq('.[0].key') | first }}

# Read and convert to JSON string:
{{ myvar | toJson }}
```

### Limitation
The `read()` function can **only read files within the same execution**. Attempting to read a file from a previous execution returns an Unauthorized error.

## inputFiles & outputFiles

### inputFiles — Provide files to a task

Files are written to the task's working directory before commands execute. Supports inline content, URIs, and all protocol schemes.

```yaml
- id: my_task
  type: io.kestra.plugin.scripts.shell.Commands
  inputFiles:
    # Inline content:
    config.json: |
      {"key": "value"}
    # From task output (kestra:// URI):
    data.csv: "{{ outputs.download.uri }}"
    # From namespace files:
    script.py: nsfile:///scripts/process.py
    # From local filesystem:
    input.csv: file:///data/input.csv
  commands:
    - python script.py  # All files available in working directory
```

### outputFiles — Capture files from a task

Files matching the patterns are uploaded to internal storage after commands complete.

```yaml
- id: generate
  type: io.kestra.plugin.scripts.shell.Commands
  commands:
    - python process.py
  outputFiles:
    - "*.csv"           # Glob pattern
    - result.json       # Exact filename
    - "reports/*.pdf"   # Directory pattern
```

Access captured files:
```yaml
{{ outputs.generate.outputFiles['result.json'] }}
{{ outputs.generate.outputFiles['report.csv'] }}
```

## Storage Management Tasks

Built-in tasks for managing internal storage files:

### Concat — Merge multiple files
```yaml
- id: merge
  type: io.kestra.plugin.core.storage.Concat
  files:
    - "{{ outputs.task1.uri }}"
    - "{{ outputs.task2.uri }}"
```

### Delete — Remove a file
```yaml
- id: cleanup
  type: io.kestra.plugin.core.storage.Delete
  uri: "{{ outputs.task1.uri }}"
```

### Size — Get file size
```yaml
- id: check_size
  type: io.kestra.plugin.core.storage.Size
  uri: "{{ outputs.task1.uri }}"
```

### Split — Partition a file
```yaml
- id: split_file
  type: io.kestra.plugin.core.storage.Split
  from: "{{ outputs.task1.uri }}"
  rows: 1000  # Split every 1000 rows
```

### Write — Write data to internal storage
```yaml
- id: write_data
  type: io.kestra.plugin.core.storage.Write
  content: "{{ outputs.someTask.body }}"
```

### PurgeExecution — Delete all execution files
```yaml
- id: purge
  type: io.kestra.plugin.core.storage.PurgeExecution
```

## Storage Backends

| Backend | Plugin | Use Case |
|---------|--------|----------|
| Local filesystem | (default) | Development only |
| AWS S3 | `kestra-storage-s3` | Production |
| Google Cloud Storage | `kestra-storage-gcs` | Production |
| Azure Blob Storage | `kestra-storage-azure` | Production |
| MinIO | `kestra-storage-s3` | Self-hosted S3-compatible |

Configuration example (S3):
```yaml
kestra:
  storage:
    type: s3
    bucket: "kestra-internal-storage"
    region: "us-east-1"
```

Default local storage path inside the Docker container: `/app/storage/main/`.

## Execution Context vs Internal Storage

| | Execution Context | Internal Storage |
|-|-------------------|------------------|
| **Size limit** | ~1MB (database row limit) | Unlimited |
| **Access** | Direct in Pebble: `{{ outputs.task.value }}` | Via URI: `{{ outputs.task.uri }}` |
| **fetchType** | `FETCH`, `FETCH_ONE` | `STORE` |
| **Best for** | Small values, configs, single records | Large files, datasets, CSVs |
| **Retention** | 7 days by default | Until purged |

## Important Limitations

1. **Execution context size**: There is a hard limit (~1MB) on execution context since it's stored as a single database row/message. Use `STORE` fetchType for larger data.

2. **read() is execution-scoped**: Files can only be read within the same execution. Cross-execution file access returns Unauthorized.

3. **ForEachItem file access**: Use `{{ read(taskrun.items) }}` to access batch content inside a ForEachItem iteration.

4. **Local filesystem access**: Requires explicit `allowed-paths` configuration and Docker bind-mounts. Unauthorized paths trigger `SecurityException`.

5. **Namespace file scope**: `nsfile:///` (three slashes) only accesses files in the current namespace. Cross-namespace requires `nsfile://other.namespace/path`.

6. **Automatic URI resolution**: Kestra's Pebble renderer automatically resolves `kestra:///` URIs found in property values. See [gotchas.md](gotchas.md) for workarounds when this causes issues.

7. **Ion as default format**: Internal storage files default to Amazon Ion format. Use Serdes plugin tasks to convert to CSV, JSON, Avro, XML, or Parquet.
