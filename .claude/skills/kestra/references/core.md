# Core Plugins Reference

Kestra's built-in orchestration, I/O, and observability capabilities.

## Table of Contents
1. [HTTP Tasks](#http-tasks)
2. [KV Store](#kv-store)
3. [Storage Tasks](#storage-tasks)
4. [Log Tasks](#log-tasks)
5. [Execution Tasks](#execution-tasks)
6. [Namespace Files](#namespace-files)
7. [Debug Tasks](#debug-tasks)
8. [Conditions](#conditions)

## HTTP Tasks

### Download
Download a file from an HTTP server to internal storage.

```yaml
- id: download
  type: io.kestra.plugin.core.http.Download
  uri: "https://example.com/data.csv"
  # Optional settings
  method: GET
  headers:
    Authorization: "Bearer {{ secret('API_TOKEN') }}"
  options:
    followRedirects: true
    allowFailed: false
  failOnEmptyFile: true
```

**Output:** `{{ outputs.download.uri }}` - Internal storage URI

### Request
Make HTTP API requests with full control.

```yaml
# GET Request
- id: get_data
  type: io.kestra.plugin.core.http.Request
  uri: "https://api.example.com/users"
  method: GET
  headers:
    Accept: application/json

# POST with JSON body
- id: post_json
  type: io.kestra.plugin.core.http.Request
  uri: "https://api.example.com/users"
  method: POST
  contentType: application/json
  body: |
    {{ {"name": inputs.name, "email": inputs.email} | json }}

# POST with form data
- id: post_form
  type: io.kestra.plugin.core.http.Request
  uri: "https://api.example.com/login"
  method: POST
  formData:
    username: "{{ inputs.user }}"
    password: "{{ inputs.pass }}"

# Multipart file upload
- id: upload_file
  type: io.kestra.plugin.core.http.Request
  uri: "https://api.example.com/upload"
  method: POST
  contentType: multipart/form-data
  formData:
    file: "{{ outputs.download.uri }}"
```

**Outputs:**
- `{{ outputs.request.body }}` - Response body
- `{{ outputs.request.headers }}` - Response headers
- `{{ outputs.request.code }}` - HTTP status code

### Authentication Options

```yaml
# Basic Auth
- id: basic_auth
  type: io.kestra.plugin.core.http.Request
  uri: "https://api.example.com/data"
  options:
    basicAuthUser: "{{ secret('API_USER') }}"
    basicAuthPassword: "{{ secret('API_PASS') }}"

# Bearer Token
- id: bearer_auth
  type: io.kestra.plugin.core.http.Request
  uri: "https://api.example.com/data"
  headers:
    Authorization: "Bearer {{ secret('API_TOKEN') }}"

# API Key in Header
- id: api_key_header
  type: io.kestra.plugin.core.http.Request
  uri: "https://api.example.com/data"
  headers:
    X-API-Key: "{{ secret('API_KEY') }}"
```

### HTTP Trigger
Trigger flow based on HTTP response.

```yaml
triggers:
  - id: http_poll
    type: io.kestra.plugin.core.http.Trigger
    uri: "https://api.example.com/status"
    responseCondition: "{{ response.statusCode == 200 }}"
    interval: PT1M
    stopAfter:
      - SUCCESS
```

## KV Store

Persist key-value pairs across executions within a namespace.

### Set
```yaml
- id: set_value
  type: io.kestra.plugin.core.kv.Set
  key: last_run_date
  value: "{{ now() }}"
  # Optional
  namespace: "{{ flow.namespace }}"  # Default: current namespace
  overwrite: true  # Default: true
  kvType: STRING  # STRING, NUMBER, BOOLEAN, DATETIME, DATE, DURATION, JSON
  ttl: P30D  # Optional TTL (ISO 8601 duration)
```

### Get
```yaml
- id: get_value
  type: io.kestra.plugin.core.kv.Get
  key: last_run_date
  namespace: "{{ flow.namespace }}"
  errorOnMissing: false  # Default: false
```

**Output:** `{{ outputs.get_value.value }}`

### Using kv() Function (Simpler)
```yaml
# Basic usage
- id: log_kv
  type: io.kestra.plugin.core.log.Log
  message: "Last run: {{ kv('last_run_date') }}"

# From another namespace
- id: log_kv_other
  type: io.kestra.plugin.core.log.Log
  message: "{{ kv('my_key', 'other.namespace') }}"

# Without error on missing
- id: log_kv_safe
  type: io.kestra.plugin.core.log.Log
  message: "{{ kv('maybe_missing', errorOnMissing=false) }}"
```

### GetKeys
```yaml
- id: list_keys
  type: io.kestra.plugin.core.kv.GetKeys
  prefix: "config_"  # Optional filter
  namespace: "{{ flow.namespace }}"
```

**Output:** `{{ outputs.list_keys.keys }}` - List of key names

### Delete
```yaml
- id: delete_key
  type: io.kestra.plugin.core.kv.Delete
  key: temporary_data
  errorOnMissing: false
```

### PurgeKV
```yaml
- id: purge_expired
  type: io.kestra.plugin.core.kv.PurgeKV
  namespaces:
    - company.team
    - company.data
  includeChildNamespaces: true
  expiredOnly: true  # Only purge expired keys
```

## Storage Tasks

Manage files in Kestra's internal storage.

### Concat
Merge multiple files into one.

```yaml
- id: concat_files
  type: io.kestra.plugin.core.storage.Concat
  files:
    - "{{ outputs.task1.uri }}"
    - "{{ outputs.task2.uri }}"
  separator: "\n"
```

**Output:** `{{ outputs.concat_files.uri }}`

### Split
Split a large file into smaller chunks.

```yaml
# Split by row count
- id: split_rows
  type: io.kestra.plugin.core.storage.Split
  from: "{{ outputs.query.uri }}"
  rows: 1000

# Split by size
- id: split_size
  type: io.kestra.plugin.core.storage.Split
  from: "{{ outputs.download.uri }}"
  bytes: "10MB"

# Split into N partitions
- id: split_partitions
  type: io.kestra.plugin.core.storage.Split
  from: "{{ outputs.download.uri }}"
  partitions: 8
```

**Output:** `{{ outputs.split_rows.uris }}` - List of file URIs

### Size
Get file size.

```yaml
- id: file_size
  type: io.kestra.plugin.core.storage.Size
  uri: "{{ outputs.download.uri }}"
```

**Output:** `{{ outputs.file_size.size }}` - Size in bytes

### Delete
Delete a file from internal storage.

```yaml
- id: cleanup
  type: io.kestra.plugin.core.storage.Delete
  uri: "{{ outputs.temp_file.uri }}"
```

### FilterItems
Filter rows in an Ion file.

```yaml
- id: filter
  type: io.kestra.plugin.core.storage.FilterItems
  from: "{{ outputs.query.uri }}"
  filterCondition: "{{ row.status == 'active' }}"
```

### DeduplicateItems
Remove duplicate rows.

```yaml
- id: dedupe
  type: io.kestra.plugin.core.storage.DeduplicateItems
  from: "{{ outputs.query.uri }}"
  keys:
    - id
    - email
```

### Write
Write content to internal storage.

```yaml
- id: write_file
  type: io.kestra.plugin.core.storage.Write
  content: |
    id,name,value
    1,test,100
```

**Output:** `{{ outputs.write_file.uri }}`

### PurgeCurrentExecutionFiles
Clean up files from current execution.

```yaml
- id: cleanup_execution
  type: io.kestra.plugin.core.storage.PurgeCurrentExecutionFiles
```

## Log Tasks

### Log
Write to execution logs.

```yaml
- id: info_log
  type: io.kestra.plugin.core.log.Log
  message: "Processing {{ outputs.count.value }} records"
  level: INFO  # TRACE, DEBUG, INFO, WARN, ERROR

# Multi-line with variables
- id: detailed_log
  type: io.kestra.plugin.core.log.Log
  message: |
    Execution Summary:
    - Records: {{ outputs.stats.records }}
    - Duration: {{ outputs.stats.duration }}
    - Status: {{ execution.state }}
```

### Fetch
Retrieve logs from executions.

```yaml
- id: fetch_logs
  type: io.kestra.plugin.core.log.Fetch
  executionId: "{{ execution.id }}"
  level: ERROR  # Minimum level to fetch
```

### PurgeLogs
Clean up old logs.

```yaml
- id: purge_old_logs
  type: io.kestra.plugin.core.log.PurgeLogs
  endDate: "{{ now() | dateAdd(-30, 'DAYS') }}"
  namespace: company.team
```

## Execution Tasks

### Fail
Intentionally fail the execution.

```yaml
# Conditional failure
- id: validate
  type: io.kestra.plugin.core.execution.Fail
  condition: "{{ outputs.check.valid == false }}"
  errorMessage: "Validation failed: {{ outputs.check.reason }}"

# Always fail (for switch default cases)
- id: invalid_case
  type: io.kestra.plugin.core.execution.Fail
  errorMessage: "Unknown case: {{ inputs.type }}"
```

### Labels
Add or update execution labels at runtime.

```yaml
- id: add_labels
  type: io.kestra.plugin.core.execution.Labels
  labels:
    customer_id: "{{ trigger.body.customerId }}"
    order_type: "{{ trigger.body.orderType }}"
    processed_by: "flow_v2"
```

### SetVariables
Modify flow variables at runtime.

```yaml
- id: update_vars
  type: io.kestra.plugin.core.execution.SetVariables
  overwrite: true
  variables:
    status: "{{ outputs.check.status }}"
    last_error: "{{ outputs.check.error ?? 'none' }}"
```

### UnsetVariables
Remove flow variables.

```yaml
- id: clear_vars
  type: io.kestra.plugin.core.execution.UnsetVariables
  variables:
    - temp_value
    - debug_flag
```

### PurgeExecutions
Clean up old executions.

```yaml
- id: purge_executions
  type: io.kestra.plugin.core.execution.PurgeExecutions
  endDate: "{{ now() | dateAdd(-90, 'DAYS') }}"
  namespace: company.team
  states:
    - SUCCESS
    - CANCELLED
```

### Assert (Testing)
Assert conditions for flow testing.

```yaml
- id: test_output
  type: io.kestra.plugin.core.execution.Assert
  conditions:
    - "{{ outputs.transform.rowCount > 0 }}"
    - "{{ outputs.transform.errorCount == 0 }}"
```

### Exit
Exit flow early without failure.

```yaml
- id: check_and_exit
  type: io.kestra.plugin.core.flow.If
  condition: "{{ outputs.check.empty == true }}"
  then:
    - id: exit_early
      type: io.kestra.plugin.core.execution.Exit
```

## Namespace Files

Manage files stored at namespace level.

### DownloadFiles
Download namespace files to working directory.

```yaml
- id: get_config
  type: io.kestra.plugin.core.namespace.DownloadFiles
  namespace: "{{ flow.namespace }}"
  files:
    - config/settings.json
    - scripts/transform.py
```

### UploadFiles
Upload files to namespace storage.

```yaml
- id: save_config
  type: io.kestra.plugin.core.namespace.UploadFiles
  namespace: "{{ flow.namespace }}"
  files:
    config/output.json: "{{ outputs.generate.uri }}"
```

### DeleteFiles
```yaml
- id: cleanup_ns
  type: io.kestra.plugin.core.namespace.DeleteFiles
  namespace: "{{ flow.namespace }}"
  files:
    - temp/*.csv
```

## Debug Tasks

### Return
Return a formatted value (useful for debugging).

```yaml
- id: debug_output
  type: io.kestra.plugin.core.debug.Return
  format: |
    Input: {{ inputs.value }}
    Transformed: {{ inputs.value | upper }}
    Timestamp: {{ now() }}
```

**Output:** `{{ outputs.debug_output.value }}`

## Conditions

Use conditions to control trigger execution.

### Expression Condition
```yaml
triggers:
  - id: webhook
    type: io.kestra.plugin.core.trigger.Webhook
    conditions:
      - type: io.kestra.plugin.core.condition.Expression
        expression: "{{ trigger.body.type == 'order' }}"
```

### Date/Time Conditions
```yaml
conditions:
  # Only on weekdays
  - type: io.kestra.plugin.core.condition.DayWeek
    dayOfWeek:
      - MONDAY
      - TUESDAY
      - WEDNESDAY
      - THURSDAY
      - FRIDAY

  # Only during business hours
  - type: io.kestra.plugin.core.condition.TimeBetween
    after: "09:00:00"
    before: "17:00:00"

  # Between specific dates
  - type: io.kestra.plugin.core.condition.DateTimeBetween
    after: "2024-01-01T00:00:00Z"
    before: "2024-12-31T23:59:59Z"

  # Skip weekends
  - type: io.kestra.plugin.core.condition.Not
    conditions:
      - type: io.kestra.plugin.core.condition.Weekend

  # Skip holidays
  - type: io.kestra.plugin.core.condition.Not
    conditions:
      - type: io.kestra.plugin.core.condition.PublicHoliday
        country: US
```

### Execution Conditions
```yaml
conditions:
  # Only for specific flow
  - type: io.kestra.plugin.core.condition.ExecutionFlow
    namespace: company.data
    flowId: etl_pipeline

  # Only on failure
  - type: io.kestra.plugin.core.condition.ExecutionStatus
    states:
      - FAILED

  # Match labels
  - type: io.kestra.plugin.core.condition.ExecutionLabels
    labels:
      environment: production
```

### Combining Conditions (OR)
```yaml
conditions:
  - type: io.kestra.plugin.core.condition.Or
    conditions:
      - type: io.kestra.plugin.core.condition.Expression
        expression: "{{ inputs.priority == 'high' }}"
      - type: io.kestra.plugin.core.condition.Expression
        expression: "{{ inputs.urgent == true }}"
```

## Complete Example: Stateful API Pipeline

```yaml
id: stateful_api_pipeline
namespace: company.data
description: Fetch data since last run using KV store

tasks:
  # Get last run timestamp from KV store
  - id: get_last_run
    type: io.kestra.plugin.core.kv.Get
    key: last_successful_run
    errorOnMissing: false

  # Set default if first run
  - id: set_since
    type: io.kestra.plugin.core.debug.Return
    format: "{{ outputs.get_last_run.value ?? '2024-01-01T00:00:00Z' }}"

  # Fetch data from API
  - id: fetch_data
    type: io.kestra.plugin.core.http.Request
    uri: "https://api.example.com/events"
    method: GET
    headers:
      Authorization: "Bearer {{ secret('API_TOKEN') }}"
      Accept: application/json
    body: |
      {{ {"since": outputs.set_since.value} | json }}

  # Validate response
  - id: validate
    type: io.kestra.plugin.core.execution.Fail
    condition: "{{ outputs.fetch_data.code != 200 }}"
    errorMessage: "API returned {{ outputs.fetch_data.code }}"

  # Process data
  - id: process
    type: io.kestra.plugin.scripts.python.Script
    containerImage: python:slim
    script: |
      import json
      from kestra import Kestra
      
      data = json.loads('''{{ outputs.fetch_data.body }}''')
      Kestra.outputs({"count": len(data.get("events", []))})

  # Log results
  - id: log_result
    type: io.kestra.plugin.core.log.Log
    message: "Processed {{ outputs.process.vars.count }} events"

  # Update last run timestamp on success
  - id: update_last_run
    type: io.kestra.plugin.core.kv.Set
    key: last_successful_run
    value: "{{ now() }}"

triggers:
  - id: hourly
    type: io.kestra.plugin.core.trigger.Schedule
    cron: "0 * * * *"
```
