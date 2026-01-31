# Script Tasks Reference

## Table of Contents
1. [Python Scripts](#python-scripts)
2. [Shell Commands](#shell-commands)
3. [Node.js Scripts](#nodejs-scripts)
4. [Task Runners](#task-runners)
5. [Dependencies & beforeCommands](#dependencies)
6. [Outputs & Metrics](#outputs-and-metrics)
7. [Input/Output Files](#input-output-files)

## Python Scripts

### Script Task (inline code)
```yaml
- id: python_inline
  type: io.kestra.plugin.scripts.python.Script
  containerImage: python:3.11-slim
  beforeCommands:
    - pip install pandas requests kestra
  script: |
    import pandas as pd
    from kestra import Kestra
    
    # Access inputs via templating
    url = "{{ inputs.api_url }}"
    
    # Process data
    df = pd.DataFrame({"col1": [1, 2, 3]})
    df.to_csv("output.csv", index=False)
    
    # Send outputs to Kestra
    Kestra.outputs({"row_count": len(df), "status": "complete"})
  outputFiles:
    - "output.csv"
```

### Commands Task (external files)
```yaml
- id: python_file
  type: io.kestra.plugin.scripts.python.Commands
  containerImage: python:3.11-slim
  namespaceFiles:
    enabled: true
    include:
      - scripts/main.py
  beforeCommands:
    - pip install -r requirements.txt
  commands:
    - python scripts/main.py
  env:
    API_URL: "{{ inputs.api_url }}"
```

### Key Python Properties
| Property | Description |
|----------|-------------|
| `containerImage` | Docker image (default: python:3-slim) |
| `script` | Inline Python code |
| `beforeCommands` | Commands before main script (pip install) |
| `afterCommands` | Commands after main script |
| `dependencies` | List of pip packages (auto-installs) |
| `outputFiles` | Files to capture (supports globs) |
| `inputFiles` | Files to inject into container |
| `env` | Environment variables |
| `namespaceFiles.enabled` | Use files from namespace |

## Shell Commands

### Shell Script (inline)
```yaml
- id: shell_script
  type: io.kestra.plugin.scripts.shell.Script
  containerImage: ubuntu:latest
  script: |
    echo "Processing file: {{ inputs.filename }}"
    curl -o data.json "{{ inputs.api_url }}"
    jq '.results[]' data.json > processed.json
  outputFiles:
    - "processed.json"
```

### Shell Commands (list)
```yaml
- id: shell_commands
  type: io.kestra.plugin.scripts.shell.Commands
  taskRunner:
    type: io.kestra.plugin.core.runner.Process
  commands:
    - echo "Start processing"
    - cat {{ outputs.download.uri }}
    - echo '::{"outputs":{"count":42,"status":"done"}}::'
```

### Output Pattern for Shell
Use `::{}::` pattern to emit outputs:
```bash
echo '::{"outputs":{"key":"value","number":123}}::'
```

## Node.js Scripts

```yaml
- id: nodejs_task
  type: io.kestra.plugin.scripts.node.Script
  containerImage: node:18-slim
  beforeCommands:
    - npm install axios
  script: |
    const axios = require('axios');
    const response = await axios.get('{{ inputs.url }}');
    console.log(JSON.stringify(response.data));
```

## Task Runners

### Docker Runner (default)
```yaml
taskRunner:
  type: io.kestra.plugin.scripts.runner.docker.Docker
  containerImage: python:3.11-slim
  credentials:
    username: myuser
    password: "{{ secret('DOCKER_PASSWORD') }}"
```

### Process Runner (host process)
```yaml
taskRunner:
  type: io.kestra.plugin.core.runner.Process
```

## Dependencies

### Using beforeCommands
```yaml
beforeCommands:
  - pip install pandas numpy requests
  - apt-get update && apt-get install -y jq
```

### Using dependencies property (Python)
```yaml
dependencies:
  - pandas
  - requests>=2.28.0
  - numpy==1.24.0
```

## Outputs and Metrics

### Python Kestra Library
```python
from kestra import Kestra

# Output variables (accessible in {{ outputs.taskId.vars.key }})
Kestra.outputs({"key": "value", "count": 42})

# Metrics (visible in Kestra UI)
Kestra.counter("processed_rows", 1000)
Kestra.timer("processing_time", 5.2)
```

### Accessing Outputs in Next Task
```yaml
- id: use_output
  type: io.kestra.plugin.core.log.Log
  message: "Previous task output: {{ outputs.python_task.vars.count }}"
```

## Input Output Files

### Passing Files Between Tasks
```yaml
tasks:
  - id: generate
    type: io.kestra.plugin.scripts.python.Script
    containerImage: python:slim
    script: |
      with open("data.csv", "w") as f:
        f.write("col1,col2\n1,2\n3,4")
    outputFiles:
      - "data.csv"
  
  - id: process
    type: io.kestra.plugin.scripts.python.Script
    containerImage: python:slim
    inputFiles:
      data.csv: "{{ outputs.generate.outputFiles['data.csv'] }}"
    script: |
      with open("data.csv") as f:
        print(f.read())
```

### Using Namespace Files
```yaml
- id: use_namespace_files
  type: io.kestra.plugin.scripts.python.Commands
  namespaceFiles:
    enabled: true
    include:
      - scripts/*.py
      - config/*.json
  commands:
    - python scripts/main.py
```
