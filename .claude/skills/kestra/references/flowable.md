# Flowable Tasks Reference

Flowable tasks control orchestration logic: branching, looping, and parallelization.

## Table of Contents
1. [Sequential](#sequential)
2. [Parallel](#parallel)
3. [If Condition](#if-condition)
4. [Switch](#switch)
5. [ForEach (Sequential)](#foreach-sequential)
6. [ForEach (Parallel)](#foreach-parallel)
7. [ForEachItem](#foreachitem)
8. [Subflow](#subflow)
9. [WorkingDirectory](#workingdirectory)
10. [AllowFailure](#allowfailure)
11. [DAG](#dag)

## Sequential

Groups tasks to run one after another.

```yaml
tasks:
  - id: sequential_group
    type: io.kestra.plugin.core.flow.Sequential
    tasks:
      - id: step1
        type: io.kestra.plugin.core.log.Log
        message: "First"
      - id: step2
        type: io.kestra.plugin.core.log.Log
        message: "Second (uses {{ outputs.step1 }})"
```

## Parallel

Runs all child tasks simultaneously.

```yaml
tasks:
  - id: parallel_group
    type: io.kestra.plugin.core.flow.Parallel
    concurrent: 3  # Optional: limit concurrent tasks (0 = unlimited)
    tasks:
      - id: task_a
        type: io.kestra.plugin.core.log.Log
        message: "Running A"
      - id: task_b
        type: io.kestra.plugin.core.log.Log
        message: "Running B"
      - id: task_c
        type: io.kestra.plugin.core.log.Log
        message: "Running C"
```

**Note:** Cannot access sibling task outputs within parallel group.

### Parallel with Sequential Groups
```yaml
tasks:
  - id: parallel_branches
    type: io.kestra.plugin.core.flow.Parallel
    tasks:
      - id: branch_a
        type: io.kestra.plugin.core.flow.Sequential
        tasks:
          - id: a1
            type: io.kestra.plugin.core.log.Log
            message: "A1"
          - id: a2
            type: io.kestra.plugin.core.log.Log
            message: "A2"
      - id: branch_b
        type: io.kestra.plugin.core.flow.Sequential
        tasks:
          - id: b1
            type: io.kestra.plugin.core.log.Log
            message: "B1"
          - id: b2
            type: io.kestra.plugin.core.log.Log
            message: "B2"
```

## If Condition

Conditional branching based on expression.

```yaml
tasks:
  - id: check_condition
    type: io.kestra.plugin.core.flow.If
    condition: "{{ inputs.environment == 'production' }}"
    then:
      - id: prod_task
        type: io.kestra.plugin.core.log.Log
        message: "Running in production"
    else:
      - id: dev_task
        type: io.kestra.plugin.core.log.Log
        message: "Running in development"
```

### If with Output Check
```yaml
- id: check_results
  type: io.kestra.plugin.core.flow.If
  condition: "{{ outputs.api_call.body | jq('.count') | first > 0 }}"
  then:
    - id: process_data
      type: io.kestra.plugin.core.log.Log
      message: "Data found, processing..."
```

## Switch

Multi-way branching based on value.

```yaml
inputs:
  - id: action
    type: STRING
    defaults: "process"

tasks:
  - id: route_action
    type: io.kestra.plugin.core.flow.Switch
    value: "{{ inputs.action }}"
    cases:
      process:
        - id: do_process
          type: io.kestra.plugin.core.log.Log
          message: "Processing data"
      export:
        - id: do_export
          type: io.kestra.plugin.core.log.Log
          message: "Exporting data"
      archive:
        - id: do_archive
          type: io.kestra.plugin.core.log.Log
          message: "Archiving data"
    defaults:
      - id: unknown_action
        type: io.kestra.plugin.core.log.Log
        message: "Unknown action: {{ inputs.action }}"
```

## ForEach Sequential

Iterate over values sequentially.

```yaml
tasks:
  - id: process_each
    type: io.kestra.plugin.core.flow.EachSequential
    value: ["file1.csv", "file2.csv", "file3.csv"]
    tasks:
      - id: process_file
        type: io.kestra.plugin.core.log.Log
        message: "Processing {{ taskrun.value }}"
```

### Dynamic Values from Previous Task
```yaml
tasks:
  - id: get_files
    type: io.kestra.plugin.scripts.shell.Commands
    commands:
      - echo '::{"outputs":{"files":["a.csv","b.csv","c.csv"]}}::'
  
  - id: process_files
    type: io.kestra.plugin.core.flow.EachSequential
    value: "{{ outputs.get_files.vars.files }}"
    tasks:
      - id: process
        type: io.kestra.plugin.core.log.Log
        message: "File: {{ taskrun.value }}"
```

## ForEach Parallel

Iterate over values in parallel.

```yaml
tasks:
  - id: parallel_process
    type: io.kestra.plugin.core.flow.EachParallel
    value: [1, 2, 3, 4, 5]
    concurrencyLimit: 2  # Max concurrent iterations
    tasks:
      - id: process_item
        type: io.kestra.plugin.scripts.shell.Commands
        commands:
          - echo "Processing item {{ taskrun.value }}"
          - sleep 5
```

## ForEachItem

Process large lists via subflows (best for millions of items).

```yaml
tasks:
  - id: batch_process
    type: io.kestra.plugin.core.flow.ForEachItem
    items: "{{ outputs.extract.uri }}"
    batch:
      rows: 100  # Items per batch
    namespace: company.team
    flowId: process_batch_subflow
    inputs:
      batch_data: "{{ taskrun.items }}"
    wait: true
    transmitFailed: true
```

## Subflow

Trigger another flow as a task.

```yaml
tasks:
  - id: call_subflow
    type: io.kestra.plugin.core.flow.Subflow
    namespace: company.team
    flowId: data_processing_flow
    inputs:
      source_file: "{{ outputs.download.uri }}"
      batch_size: 1000
    wait: true  # Wait for completion
    transmitFailed: true  # Fail if subflow fails
```

### Access Subflow Outputs
```yaml
- id: use_subflow_output
  type: io.kestra.plugin.core.log.Log
  message: "Subflow result: {{ outputs.call_subflow.outputs.result }}"
```

## WorkingDirectory

Share files between tasks in same working directory.

```yaml
tasks:
  - id: shared_workspace
    type: io.kestra.plugin.core.flow.WorkingDirectory
    tasks:
      - id: create_file
        type: io.kestra.plugin.scripts.shell.Commands
        commands:
          - echo "data" > shared.txt
      - id: read_file
        type: io.kestra.plugin.scripts.shell.Commands
        commands:
          - cat shared.txt  # File exists from previous task
```

## AllowFailure

Continue execution even if task fails (marks as WARNING).

```yaml
tasks:
  - id: optional_step
    type: io.kestra.plugin.core.flow.AllowFailure
    tasks:
      - id: might_fail
        type: io.kestra.plugin.scripts.shell.Commands
        commands:
          - exit 1  # This failure won't stop the flow
  
  - id: continues_anyway
    type: io.kestra.plugin.core.log.Log
    message: "This runs even if previous failed"
```

## DAG

Declare task dependencies explicitly (Kestra resolves order).

```yaml
tasks:
  - id: dag_flow
    type: io.kestra.plugin.core.flow.Dag
    tasks:
      - task:
          id: extract
          type: io.kestra.plugin.core.log.Log
          message: "Extracting"
      - task:
          id: transform
          type: io.kestra.plugin.core.log.Log
          message: "Transforming"
        dependsOn:
          - extract
      - task:
          id: load
          type: io.kestra.plugin.core.log.Log
          message: "Loading"
        dependsOn:
          - transform
```

## Accessing Loop Variables

| Variable | Description |
|----------|-------------|
| `{{ taskrun.value }}` | Current iteration value |
| `{{ taskrun.iteration }}` | Current iteration index (0-based) |
| `{{ parent.taskrun.value }}` | Parent loop value (nested loops) |
| `{{ outputs.taskId[taskrun.value].property }}` | Output from specific iteration |
