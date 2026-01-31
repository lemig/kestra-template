# Pebble Templating & Expressions Reference

Kestra uses Pebble templating for dynamic values.

## Table of Contents
1. [Basic Syntax](#basic-syntax)
2. [Built-in Variables](#built-in-variables)
3. [Filters](#filters)
4. [Functions](#functions)
5. [JQ Expressions](#jq-expressions)
6. [Conditionals](#conditionals)
7. [Loops](#loops)

## Basic Syntax

```yaml
# Variable interpolation
message: "Hello {{ inputs.name }}"

# With filters
message: "{{ inputs.name | upper }}"

# Nested properties
message: "{{ outputs.api_call.body.data.id }}"

# Default values
message: "{{ inputs.name | default('World') }}"
```

## Built-in Variables

### Flow Variables
| Variable | Description |
|----------|-------------|
| `{{ flow.id }}` | Flow ID |
| `{{ flow.namespace }}` | Flow namespace |
| `{{ flow.revision }}` | Flow revision number |

### Execution Variables
| Variable | Description |
|----------|-------------|
| `{{ execution.id }}` | Execution ID |
| `{{ execution.startDate }}` | Execution start datetime |
| `{{ execution.state }}` | Current execution state |

### Task Variables
| Variable | Description |
|----------|-------------|
| `{{ task.id }}` | Current task ID |
| `{{ task.type }}` | Current task type |
| `{{ taskrun.id }}` | Current task run ID |
| `{{ taskrun.startDate }}` | Task run start datetime |
| `{{ taskrun.attemptsCount }}` | Number of retry attempts |
| `{{ taskrun.value }}` | Current iteration value (in loops) |
| `{{ taskrun.iteration }}` | Current iteration index |

### Input/Output Variables
| Variable | Description |
|----------|-------------|
| `{{ inputs.inputId }}` | Access input value |
| `{{ inputs['input-id'] }}` | Input with special characters |
| `{{ outputs.taskId.property }}` | Task output property |
| `{{ outputs.taskId.vars.key }}` | Script output variable |
| `{{ outputs.taskId.outputFiles['file.csv'] }}` | Output file URI |

### Trigger Variables
| Variable | Description |
|----------|-------------|
| `{{ trigger.date }}` | Trigger date |
| `{{ trigger.body }}` | Webhook body |
| `{{ trigger.headers }}` | Webhook headers |
| `{{ trigger.uri }}` | File trigger URI |

### Other Variables
| Variable | Description |
|----------|-------------|
| `{{ vars.key }}` | Flow-level variable |
| `{{ labels.key }}` | Flow label value |
| `{{ secret('NAME') }}` | Secret value |
| `{{ envs.VAR_NAME }}` | Environment variable |

## Filters

### String Filters
```yaml
# Case transformation
message: "{{ inputs.name | upper }}"      # HELLO
message: "{{ inputs.name | lower }}"      # hello
message: "{{ inputs.name | capitalize }}" # Hello

# Trimming
message: "{{ inputs.text | trim }}"

# Substring
message: "{{ inputs.text | slice(0, 5) }}"

# Replace
message: "{{ inputs.text | replace('old', 'new') }}"

# URL encoding
url: "{{ inputs.query | urlEncode }}"

# Base64
encoded: "{{ inputs.data | base64encode }}"
decoded: "{{ inputs.encoded | base64decode }}"

# Abbreviate
short: "{{ inputs.long_text | abbreviate(20) }}"
```

### Number Filters
```yaml
# Formatting
formatted: "{{ inputs.number | numberFormat('#,##0.00') }}"

# Rounding
rounded: "{{ inputs.decimal | round }}"
```

### Date Filters
```yaml
# Format dates
date: "{{ execution.startDate | date('yyyy-MM-dd') }}"
time: "{{ execution.startDate | date('HH:mm:ss') }}"

# Date arithmetic
tomorrow: "{{ execution.startDate | dateAdd(1, 'DAYS') }}"
last_week: "{{ now() | dateAdd(-7, 'DAYS') }}"

# Timestamp
epoch: "{{ execution.startDate | timestamp }}"
```

### Collection Filters
```yaml
# First/Last
first_item: "{{ outputs.list.items | first }}"
last_item: "{{ outputs.list.items | last }}"

# Size
count: "{{ outputs.list.items | length }}"

# Join
csv: "{{ outputs.list.items | join(',') }}"

# Sort
sorted: "{{ outputs.list.items | sort }}"

# Reverse
reversed: "{{ outputs.list.items | reverse }}"

# Keys/Values (for maps)
all_keys: "{{ outputs.data.map | keys }}"
all_values: "{{ outputs.data.map | values }}"
```

### JSON Filters
```yaml
# Parse JSON string into object
parsed: "{{ inputs.json_string | json }}"

# Convert object/array to JSON string
json_string: "{{ outputs.data | json }}"

# Safe string escaping for JSON body interpolation
# Outputs a quoted+escaped JSON string: "value with \"quotes\""
# Do NOT wrap in additional quotes — the filter adds them
body: |
  {
    "Name": {{ outputs.extract_fields.values.name | json }},
    "Items": {{ vars.itemList | json }}
  }

# String concatenation before JSON escaping (use ~ operator)
body: |
  {"Search": [{{ (inputs.query ~ "*") | json }}]}

# Pretty print
pretty: "{{ outputs.data | jsonWriter({pretty: true}) }}"
```

> **Critical:** When building JSON bodies in HTTP Request tasks, ALWAYS use `{{ value | json }}` (no surrounding quotes) for any user-supplied or variable data. Direct interpolation like `"{{ value }}"` breaks when the value contains double quotes. See [gotchas.md](gotchas.md#json-body-interpolation-with--json-filter) for details.

## Functions

### Date/Time Functions
```yaml
# Current datetime
now: "{{ now() }}"

# Specific date
date: "{{ date('2024-01-15') }}"

# Current timestamp
ts: "{{ timestamp() }}"
```

### Utility Functions
```yaml
# Generate UUID
id: "{{ uuid() }}"

# Check if null
is_empty: "{{ inputs.value is empty }}"

# Read file content
content: "{{ read(outputs.download.uri) }}"

# Render template
rendered: "{{ render(vars.template) }}"
```

### Secret Function
```yaml
# Access secrets
api_key: "{{ secret('API_KEY') }}"
db_password: "{{ secret('DB_PASSWORD') }}"
```

## JQ Expressions

Use `jq()` filter for JSON manipulation.

```yaml
# Extract field
value: "{{ outputs.api.body | jq('.data.id') | first }}"

# Filter array
filtered: "{{ outputs.api.body | jq('.items[] | select(.status == \"active\")') }}"

# Map values
names: "{{ outputs.api.body | jq('.users[].name') }}"

# Count items
count: "{{ outputs.api.body | jq('.items | length') | first }}"

# Complex query
result: "{{ outputs.api.body | jq('.data[] | select(.price > 100) | .name') }}"
```

**Note:** `jq()` returns an array, use `| first` to get single value.

## Conditionals

### Ternary Operator
```yaml
message: "{{ inputs.count > 0 ? 'Has items' : 'Empty' }}"
```

### Null Coalescing
```yaml
# Default if null
value: "{{ inputs.optional ?? 'default' }}"
```

### In If Tasks
```yaml
- id: check
  type: io.kestra.plugin.core.flow.If
  condition: "{{ outputs.api.body | jq('.status') | first == 'success' }}"
  then:
    - id: success_task
      type: io.kestra.plugin.core.log.Log
      message: "Success!"
```

## Loops

### In Pebble Templates
```yaml
script: |
  {% for item in outputs.list.items %}
  Processing: {{ item }}
  {% endfor %}
```

### ForEach Tasks
```yaml
- id: loop
  type: io.kestra.plugin.core.flow.EachSequential
  value: "{{ outputs.get_items.vars.items }}"
  tasks:
    - id: process
      type: io.kestra.plugin.core.log.Log
      message: "Item: {{ taskrun.value }}"
```

## Common Patterns

### Accessing Nested JSON
```yaml
# Direct access
value: "{{ outputs.api.body.data.items[0].name }}"

# With jq (safer)
value: "{{ outputs.api.body | jq('.data.items[0].name') | first }}"
```

### Handling Optional Values
```yaml
# With default
value: "{{ inputs.optional | default('fallback') }}"

# Null check
value: "{{ inputs.value ?? 'was null' }}"
```

### Dynamic File Paths
```yaml
path: "data/{{ execution.startDate | date('yyyy/MM/dd') }}/output.csv"
```

### Conditional Script Content
```yaml
script: |
  {% if inputs.debug %}
  print("Debug mode enabled")
  {% endif %}
  print("Processing...")
```
