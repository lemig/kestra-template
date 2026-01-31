# Best Practices Reference

Production patterns for Kestra workflows: task runners, subflows, Python business logic, and performance optimization.

## Table of Contents
1. [Task Runners](#task-runners)
2. [Subflows Architecture](#subflows-architecture)
3. [Python Business Logic Patterns](#python-business-logic-patterns)
4. [Plugin Defaults](#plugin-defaults)
5. [Performance Optimization](#performance-optimization)
6. [Namespace Organization](#namespace-organization)
7. [Error Handling Patterns](#error-handling-patterns)

## Task Runners

Task runners control where and how your code executes.

### Docker Task Runner (Default)
```yaml
- id: python_docker
  type: io.kestra.plugin.scripts.python.Script
  containerImage: python:3.11-slim
  taskRunner:
    type: io.kestra.plugin.scripts.runner.docker.Docker
    cpu:
      cpus: 2
    memory:
      memory: "2GB"
    credentials:
      username: myuser
      password: "{{ secret('DOCKER_PASSWORD') }}"
  script: |
    print("Running in Docker container")
```

### Process Task Runner (Host)
```yaml
- id: python_process
  type: io.kestra.plugin.scripts.python.Script
  taskRunner:
    type: io.kestra.plugin.core.runner.Process
  script: |
    # Runs on Kestra worker host
    # Use for: GPU access, local files, pre-installed software
    print("Running on host")
```

### Kubernetes Task Runner (Enterprise)
```yaml
- id: k8s_task
  type: io.kestra.plugin.scripts.python.Script
  containerImage: ghcr.io/kestra-io/pydata:latest
  taskRunner:
    type: io.kestra.plugin.ee.kubernetes.runner.Kubernetes
    namespace: kestra-tasks
    pullPolicy: ALWAYS
    resources:
      request:
        cpu: "500m"
        memory: "512Mi"
      limit:
        cpu: "2000m"
        memory: "4Gi"
  script: |
    print("Running in Kubernetes")
```

### Setting Default Task Runner
```yaml
# Flow-level default
pluginDefaults:
  - type: io.kestra.plugin.scripts.python
    values:
      containerImage: python:3.11-slim
      taskRunner:
        type: io.kestra.plugin.scripts.runner.docker.Docker
        cpu:
          cpus: 1
```

## Subflows Architecture

Use subflows to modularize workflows and manage complexity.

### When to Use Subflows
- **Reusable components** (notifications, data validation)
- **Large workflows** (>100 tasks cause performance issues)
- **Isolation** (separate execution contexts)
- **Team boundaries** (different teams own different flows)

### Basic Subflow Pattern
```yaml
# Parent flow
id: parent_orchestrator
namespace: company.data

tasks:
  - id: extract
    type: io.kestra.plugin.core.flow.Subflow
    namespace: company.data
    flowId: extract_data
    inputs:
      source: "{{ inputs.source }}"
    wait: true
    transmitFailed: true

  - id: transform
    type: io.kestra.plugin.core.flow.Subflow
    namespace: company.data
    flowId: transform_data
    inputs:
      data_uri: "{{ outputs.extract.outputs.data_uri }}"
    wait: true
    transmitFailed: true

  - id: load
    type: io.kestra.plugin.core.flow.Subflow
    namespace: company.data
    flowId: load_data
    inputs:
      data_uri: "{{ outputs.transform.outputs.transformed_uri }}"
    wait: true
    transmitFailed: true
```

### Subflow with Outputs
```yaml
# Subflow (child)
id: extract_data
namespace: company.data

inputs:
  - id: source
    type: STRING

tasks:
  - id: fetch
    type: io.kestra.plugin.core.http.Download
    uri: "{{ inputs.source }}"

# Expose outputs to parent
outputs:
  - id: data_uri
    type: STRING
    value: "{{ outputs.fetch.uri }}"
```

### ForEachItem with Subflows (Batch Processing)
```yaml
- id: batch_process
  type: io.kestra.plugin.core.flow.ForEachItem
  items: "{{ outputs.get_records.uri }}"
  batch:
    rows: 100  # Process 100 records per subflow
  namespace: company.data
  flowId: process_batch
  inputs:
    batch_data: "{{ taskrun.items }}"
  wait: true
  transmitFailed: true
  concurrencyLimit: 5  # Max parallel subflows
```

### Important: Subflow Properties
| Property | Description | Default |
|----------|-------------|---------|
| `wait` | Wait for completion | `false` |
| `transmitFailed` | Fail parent if subflow fails | `false` |
| `inheritLabels` | Pass parent labels | `false` |
| `revision` | Specific flow revision | latest |

## Python Business Logic Patterns

### Prefer Commands Over Script for Complex Logic
```yaml
# BAD: Long inline script
- id: process
  type: io.kestra.plugin.scripts.python.Script
  script: |
    # 200 lines of Python...

# GOOD: External file via Commands
- id: process
  type: io.kestra.plugin.scripts.python.Commands
  containerImage: python:3.11-slim
  namespaceFiles:
    enabled: true
    include:
      - scripts/process_data.py
      - scripts/utils.py
  beforeCommands:
    - pip install -r scripts/requirements.txt
  commands:
    - python scripts/process_data.py
  env:
    INPUT_URI: "{{ outputs.download.uri }}"
    OUTPUT_DIR: "{{ workingDir }}"
```

### Passing Data to Python
```yaml
# Method 1: Environment variables
- id: python
  type: io.kestra.plugin.scripts.python.Commands
  commands:
    - python main.py
  env:
    API_URL: "{{ inputs.api_url }}"
    BATCH_SIZE: "{{ inputs.batch_size }}"

# Method 2: Pebble templating in script
- id: python
  type: io.kestra.plugin.scripts.python.Script
  script: |
    url = "{{ inputs.api_url }}"
    batch_size = {{ inputs.batch_size }}

# Method 3: Input files
- id: python
  type: io.kestra.plugin.scripts.python.Script
  inputFiles:
    data.csv: "{{ outputs.download.uri }}"
    config.json: |
      {"batch_size": {{ inputs.batch_size }}}
  script: |
    import json
    with open("config.json") as f:
      config = json.load(f)
```

### Emitting Outputs from Python
```yaml
- id: python_with_outputs
  type: io.kestra.plugin.scripts.python.Script
  containerImage: python:3.11-slim
  beforeCommands:
    - pip install kestra
  script: |
    from kestra import Kestra
    
    # Output variables (accessible via {{ outputs.python_with_outputs.vars.key }})
    Kestra.outputs({
      "row_count": 1000,
      "status": "success",
      "errors": []
    })
    
    # Metrics (visible in Kestra UI)
    Kestra.counter("rows_processed", 1000)
    Kestra.timer("processing_time", 45.2)
  outputFiles:
    - "*.csv"  # Capture output files
```

### WorkingDirectory for Multi-Step Processing
```yaml
- id: data_pipeline
  type: io.kestra.plugin.core.flow.WorkingDirectory
  inputFiles:
    input.csv: "{{ outputs.download.uri }}"
  tasks:
    - id: step1_clean
      type: io.kestra.plugin.scripts.python.Script
      containerImage: python:slim
      beforeCommands:
        - pip install pandas
      script: |
        import pandas as pd
        df = pd.read_csv("input.csv")
        df.dropna().to_csv("cleaned.csv", index=False)
    
    - id: step2_transform
      type: io.kestra.plugin.scripts.python.Script
      containerImage: python:slim
      beforeCommands:
        - pip install pandas
      script: |
        import pandas as pd
        df = pd.read_csv("cleaned.csv")  # From previous step
        df['total'] = df['price'] * df['quantity']
        df.to_csv("transformed.csv", index=False)
      outputFiles:
        - "transformed.csv"
```

## Plugin Defaults

### Hierarchy
1. **Task-level** (highest priority)
2. **Flow-level** `pluginDefaults`
3. **Namespace-level** (Enterprise)
4. **Global configuration** (lowest priority)

### Flow-Level Defaults
```yaml
id: my_flow
namespace: company.team

pluginDefaults:
  # All Python tasks use this image
  - type: io.kestra.plugin.scripts.python
    values:
      containerImage: ghcr.io/company/python:3.11
      taskRunner:
        type: io.kestra.plugin.scripts.runner.docker.Docker
  
  # All HTTP requests use these headers
  - type: io.kestra.plugin.core.http.Request
    values:
      headers:
        Authorization: "Bearer {{ secret('API_TOKEN') }}"

tasks:
  - id: python1
    type: io.kestra.plugin.scripts.python.Script
    # Uses default containerImage from pluginDefaults
    script: print("Hello")
  
  - id: python2
    type: io.kestra.plugin.scripts.python.Script
    containerImage: python:3.12-slim  # Overrides default
    script: print("World")
```

### Forced Defaults
```yaml
pluginDefaults:
  - type: io.kestra.plugin.scripts.python
    forced: true  # Cannot be overridden at task level
    values:
      taskRunner:
        type: io.kestra.plugin.scripts.runner.docker.Docker
```

## Performance Optimization

### Avoid Large Execution Context
```yaml
# BAD: Fetching large data into memory
- id: query
  type: io.kestra.plugin.jdbc.postgresql.Query
  sql: SELECT * FROM huge_table
  fetch: true  # Loads all data into execution context!

# GOOD: Store to internal storage
- id: query
  type: io.kestra.plugin.jdbc.postgresql.Query
  sql: SELECT * FROM huge_table
  store: true  # Stores as file, returns URI
  fetchSize: 10000  # Streaming batch size
```

### Use Subflows for Large Workflows
```yaml
# BAD: 200 tasks in one flow
# (causes serialization overhead on each task state change)

# GOOD: Break into subflows
- id: phase1
  type: io.kestra.plugin.core.flow.Subflow
  flowId: etl_extract
  wait: true

- id: phase2
  type: io.kestra.plugin.core.flow.Subflow
  flowId: etl_transform
  wait: true
```

### Parallel Processing with Limits
```yaml
- id: parallel_tasks
  type: io.kestra.plugin.core.flow.Parallel
  concurrent: 5  # Limit concurrent tasks
  tasks:
    - id: task1
      type: ...
    - id: task2
      type: ...
```

### Use Timeout
```yaml
- id: long_task
  type: io.kestra.plugin.scripts.python.Script
  timeout: PT30M  # Fail after 30 minutes
  script: |
    # Long-running process
```

## Namespace Organization

### Recommended Structure
```
company/
├── prod/
│   ├── data/          # Production data pipelines
│   ├── ml/            # ML workflows
│   └── ops/           # Operations/monitoring
├── staging/
│   ├── data/
│   └── ml/
└── dev/
    ├── experiments/
    └── testing/
```

### Labels for Organization
```yaml
id: daily_etl
namespace: company.prod.data
labels:
  team: data-engineering
  owner: john.doe
  priority: high
  environment: production
```

## Error Handling Patterns

### Centralized Alerting
```yaml
# monitoring/alert_on_failure.yaml
id: alert_on_failure
namespace: company.monitoring

tasks:
  - id: slack_alert
    type: io.kestra.plugin.notifications.slack.SlackIncomingWebhook
    url: "{{ secret('SLACK_WEBHOOK') }}"
    messageText: |
      🚨 Flow Failed!
      Flow: {{ trigger.flowId }}
      Namespace: {{ trigger.namespace }}
      Execution: {{ trigger.executionId }}

triggers:
  - id: any_failure
    type: io.kestra.plugin.core.trigger.Flow
    preconditions:
      id: watch_all
      flows:
        - namespace: company.prod
          flowId: "*"  # All flows
          states: [FAILED]
```

### Retry with Alerting
```yaml
- id: critical_task
  type: io.kestra.plugin.core.http.Request
  uri: "{{ inputs.api_url }}"
  retry:
    type: exponential
    maxAttempts: 5
    interval: PT10S
    maxInterval: PT5M
    warningOnRetry: true  # Log warning on each retry

errors:
  - id: alert_after_all_retries_fail
    type: io.kestra.plugin.notifications.slack.SlackIncomingWebhook
    url: "{{ secret('SLACK_WEBHOOK') }}"
    messageText: "Critical task failed after all retries"
```

### Graceful Degradation
```yaml
tasks:
  - id: primary_source
    type: io.kestra.plugin.core.flow.AllowFailure
    tasks:
      - id: fetch_primary
        type: io.kestra.plugin.core.http.Request
        uri: "https://primary-api.example.com/data"
  
  - id: fallback_check
    type: io.kestra.plugin.core.flow.If
    condition: "{{ outputs.primary_source.state == 'FAILED' }}"
    then:
      - id: fetch_fallback
        type: io.kestra.plugin.core.http.Request
        uri: "https://backup-api.example.com/data"
```
