# Triggers Reference

## Table of Contents
1. [Schedule Trigger](#schedule-trigger)
2. [Webhook Trigger](#webhook-trigger)
3. [Flow Trigger](#flow-trigger)
4. [Polling Triggers](#polling-triggers)
5. [Trigger Variables](#trigger-variables)
6. [Conditions](#conditions)

## Schedule Trigger

### Basic Cron Schedule
```yaml
triggers:
  - id: daily_schedule
    type: io.kestra.plugin.core.trigger.Schedule
    cron: "0 9 * * *"  # Every day at 9 AM UTC
```

### Cron Expression Format
```
┌───────────── minute (0-59)
│ ┌───────────── hour (0-23)
│ │ ┌───────────── day of month (1-31)
│ │ │ ┌───────────── month (1-12)
│ │ │ │ ┌───────────── day of week (0-7, 0 and 7 = Sunday)
│ │ │ │ │
* * * * *
```

### Cron Shortcuts
| Shortcut | Equivalent | Description |
|----------|------------|-------------|
| `@yearly` | `0 0 1 1 *` | Once a year (Jan 1) |
| `@monthly` | `0 0 1 * *` | Once a month (1st) |
| `@weekly` | `0 0 * * 0` | Once a week (Sunday) |
| `@daily` | `0 0 * * *` | Once a day (midnight) |
| `@hourly` | `0 * * * *` | Once an hour |

### Schedule with Timezone
```yaml
triggers:
  - id: schedule
    type: io.kestra.plugin.core.trigger.Schedule
    cron: "0 9 * * 1-5"  # Weekdays at 9 AM
    timezone: America/New_York
```

### Schedule with Inputs
```yaml
triggers:
  - id: schedule
    type: io.kestra.plugin.core.trigger.Schedule
    cron: "@daily"
    inputs:
      environment: production
      batch_size: 1000
```

### Backfill & Recovery
```yaml
triggers:
  - id: schedule
    type: io.kestra.plugin.core.trigger.Schedule
    cron: "0 * * * *"
    recoverMissedSchedules: ALL  # ALL, LAST, NONE
```

### Stop After Failure
```yaml
triggers:
  - id: critical_job
    type: io.kestra.plugin.core.trigger.Schedule
    cron: "0 9 * * *"
    stopAfter:
      - FAILED
```

## Webhook Trigger

### Basic Webhook
```yaml
triggers:
  - id: webhook
    type: io.kestra.plugin.core.trigger.Webhook
    key: "{{ secret('WEBHOOK_KEY') }}"  # Or hardcoded: my-secret-key
```

**Webhook URL Format:**
```
POST https://{kestra-host}/api/v1/main/executions/webhook/{namespace}/{flowId}/{key}
```

### Accessing Webhook Data
```yaml
tasks:
  - id: process_webhook
    type: io.kestra.plugin.core.log.Log
    message: |
      Body: {{ trigger.body }}
      Headers: {{ trigger.headers }}
```

### Webhook with Conditions
```yaml
triggers:
  - id: github_webhook
    type: io.kestra.plugin.core.trigger.Webhook
    key: github-secret
    conditions:
      - type: io.kestra.plugin.core.condition.ExpressionCondition
        expression: "{{ trigger.body.action == 'opened' }}"
```

## Flow Trigger

### Trigger on Another Flow's Completion
```yaml
triggers:
  - id: upstream_complete
    type: io.kestra.plugin.core.trigger.Flow
    inputs:
      data_file: "{{ trigger.outputs.extract_data.uri }}"
    preconditions:
      id: check_upstream
      flows:
        - namespace: company.data
          flowId: extract_job
          states: [SUCCESS]
      timeWindow:
        type: SLIDING_WINDOW
        window: PT1H
```

### Multiple Flow Dependencies
```yaml
triggers:
  - id: multi_dependency
    type: io.kestra.plugin.core.trigger.Flow
    preconditions:
      id: wait_for_all
      flows:
        - namespace: company.team
          flowId: flow_a
          states: [SUCCESS]
        - namespace: company.team
          flowId: flow_b
          states: [SUCCESS]
      timeWindow:
        type: DAILY_TIME_DEADLINE
        deadline: "09:00:00+00:00"
```

## Polling Triggers

### HTTP Polling
```yaml
triggers:
  - id: poll_api
    type: io.kestra.plugin.core.http.Trigger
    uri: "https://api.example.com/status"
    method: GET
    interval: PT5M
    conditions:
      - type: io.kestra.plugin.core.condition.ExpressionCondition
        expression: "{{ trigger.body.status == 'ready' }}"
```

### File Detection (S3 example)
```yaml
triggers:
  - id: s3_file
    type: io.kestra.plugin.aws.s3.Trigger
    bucket: my-bucket
    prefix: incoming/
    interval: PT1M
    action: MOVE
    moveTo:
      bucket: my-bucket
      key: processed/{{ trigger.objects[0].key }}
```

## Trigger Variables

| Variable | Description |
|----------|-------------|
| `{{ trigger.date }}` | Current schedule date |
| `{{ trigger.next }}` | Next schedule date |
| `{{ trigger.previous }}` | Previous schedule date |
| `{{ trigger.body }}` | Webhook request body |
| `{{ trigger.headers }}` | Webhook request headers |
| `{{ trigger.uri }}` | File trigger URI |
| `{{ trigger.outputs }}` | Flow trigger outputs |
| `{{ trigger.executionId }}` | Triggering execution ID |
| `{{ trigger.namespace }}` | Triggering flow namespace |
| `{{ trigger.flowId }}` | Triggering flow ID |

## Conditions

### Day of Week
```yaml
conditions:
  - type: io.kestra.plugin.core.condition.DayWeek
    dayOfWeek: "MONDAY"
```

### Date Range
```yaml
conditions:
  - type: io.kestra.plugin.core.condition.DateTimeBetween
    after: "2024-01-01T00:00:00Z"
    before: "2024-12-31T23:59:59Z"
```

### Expression Condition
```yaml
conditions:
  - type: io.kestra.plugin.core.condition.ExpressionCondition
    expression: "{{ inputs.env == 'production' }}"
```

### Execution Status Condition
```yaml
conditions:
  - type: io.kestra.plugin.core.condition.ExecutionStatusCondition
    in: [SUCCESS, WARNING]
```
