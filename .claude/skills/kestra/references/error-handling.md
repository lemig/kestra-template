# Error Handling & Retries Reference

## Table of Contents
1. [Flow-Level Error Handling](#flow-level-error-handling)
2. [Local Error Handling](#local-error-handling)
3. [Retries](#retries)
4. [Timeout](#timeout)
5. [AllowFailure](#allowfailure)
6. [AllowWarning](#allowwarning)
7. [Fail Task](#fail-task)
8. [Notifications](#notifications)

## Flow-Level Error Handling

Define tasks that run when any task fails.

```yaml
id: flow_with_errors
namespace: company.team

tasks:
  - id: might_fail
    type: io.kestra.plugin.scripts.shell.Commands
    commands:
      - exit 1

errors:
  - id: error_notification
    type: io.kestra.plugin.core.log.Log
    message: "Flow failed! Task: {{ errorLogs()[0]['taskId'] }}"
  
  - id: slack_alert
    type: io.kestra.plugin.notifications.slack.SlackIncomingWebhook
    url: "{{ secret('SLACK_WEBHOOK') }}"
    messageText: |
      🚨 Flow Failed!
      Flow: {{ flow.namespace }}.{{ flow.id }}
      Execution: {{ execution.id }}
```

## Local Error Handling

Handle errors for specific task groups.

```yaml
tasks:
  - id: critical_section
    type: io.kestra.plugin.core.flow.Sequential
    tasks:
      - id: step1
        type: io.kestra.plugin.core.log.Log
        message: "Step 1"
      - id: step2_fails
        type: io.kestra.plugin.scripts.shell.Commands
        commands:
          - exit 1
    errors:
      - id: cleanup
        type: io.kestra.plugin.core.log.Log
        message: "Cleaning up after failure in critical section"
```

## Retries

### Constant Retry
```yaml
- id: api_call
  type: io.kestra.plugin.core.http.Request
  uri: "https://api.example.com/data"
  retry:
    type: constant
    maxAttempts: 5
    interval: PT30S  # 30 seconds between retries
    maxDuration: PT10M  # Stop retrying after 10 minutes
    warningOnRetry: true  # Log warning on each retry
```

### Exponential Backoff
```yaml
- id: with_backoff
  type: io.kestra.plugin.core.http.Request
  uri: "https://api.example.com/data"
  retry:
    type: exponential
    maxAttempts: 5
    interval: PT1S
    maxInterval: PT5M
    delayFactor: 2.0  # Double the interval each retry
```

### Random Retry
```yaml
- id: random_retry
  type: io.kestra.plugin.core.http.Request
  uri: "https://api.example.com/data"
  retry:
    type: random
    maxAttempts: 5
    minInterval: PT5S
    maxInterval: PT30S
```

### Retry Properties

| Property | Description |
|----------|-------------|
| `type` | `constant`, `exponential`, `random` |
| `maxAttempts` | Maximum number of attempts |
| `interval` | Base interval between retries |
| `maxDuration` | Maximum total retry duration |
| `maxInterval` | Maximum interval (exponential/random) |
| `minInterval` | Minimum interval (random) |
| `delayFactor` | Multiplier for exponential backoff |
| `warningOnRetry` | Emit warning on retry |

### Tracking Retry Attempts
```yaml
- id: retry_aware
  type: io.kestra.plugin.scripts.shell.Commands
  commands:
    - echo "Attempt {{ taskrun.attemptsCount }}"
    - |
      if [ "{{ taskrun.attemptsCount }}" -eq 4 ]; then
        exit 0  # Succeed on 5th attempt
      else
        exit 1  # Fail first 4 attempts
      fi
  retry:
    type: constant
    maxAttempts: 5
    interval: PT1S
```

## Timeout

Set maximum duration for a task.

```yaml
- id: long_running_task
  type: io.kestra.plugin.scripts.python.Script
  timeout: PT30M  # 30 minutes
  containerImage: python:slim
  script: |
    import time
    time.sleep(3600)  # This will timeout after 30 min
```

### Timeout with Retry
```yaml
- id: task_with_both
  type: io.kestra.plugin.core.http.Request
  uri: "https://slow-api.example.com"
  timeout: PT5M  # Per-attempt timeout
  retry:
    type: constant
    maxAttempts: 3
    interval: PT1M
    maxDuration: PT30M  # Total retry duration
```

## AllowFailure

Continue flow even if task fails (execution ends with WARNING).

```yaml
tasks:
  - id: optional
    type: io.kestra.plugin.core.flow.AllowFailure
    tasks:
      - id: might_fail
        type: io.kestra.plugin.scripts.shell.Commands
        commands:
          - exit 1
  
  - id: continues
    type: io.kestra.plugin.core.log.Log
    message: "This still runs"
```

## AllowWarning

Continue without warning status if task emits warning.

```yaml
- id: warn_task
  type: io.kestra.plugin.scripts.python.Script
  allowWarning: true
  containerImage: python:slim
  beforeCommands:
    - pip install kestra
  script: |
    from kestra import Kestra
    logger = Kestra.logger()
    logger.warning("This warning won't affect flow status")
```

## Fail Task

Explicitly fail the flow based on condition.

```yaml
tasks:
  - id: validate
    type: io.kestra.plugin.core.http.Request
    uri: "https://api.example.com/status"
  
  - id: fail_if_invalid
    type: io.kestra.plugin.core.execution.Fail
    condition: "{{ outputs.validate.body | jq('.status') | first != 'ready' }}"
    message: "API not ready, aborting flow"
```

## Notifications

### Slack
```yaml
errors:
  - id: slack_error
    type: io.kestra.plugin.notifications.slack.SlackIncomingWebhook
    url: "{{ secret('SLACK_WEBHOOK') }}"
    messageText: |
      :x: Flow Failed
      *Flow:* {{ flow.namespace }}.{{ flow.id }}
      *Execution:* {{ execution.id }}
```

### Email
```yaml
errors:
  - id: email_alert
    type: io.kestra.plugin.notifications.mail.MailSend
    host: smtp.example.com
    port: 587
    username: "{{ secret('SMTP_USER') }}"
    password: "{{ secret('SMTP_PASS') }}"
    from: alerts@example.com
    to: team@example.com
    subject: "Kestra Flow Failed: {{ flow.id }}"
    htmlTextContent: |
      <h2>Flow Execution Failed</h2>
      <p>Flow: {{ flow.namespace }}.{{ flow.id }}</p>
      <p>Execution ID: {{ execution.id }}</p>
```

### Namespace-Level Alerting
Create a monitoring flow triggered by any failure:

```yaml
id: namespace_alerts
namespace: company.team

tasks:
  - id: alert
    type: io.kestra.plugin.notifications.slack.SlackIncomingWebhook
    url: "{{ secret('SLACK_WEBHOOK') }}"
    messageText: "Flow {{ trigger.flowId }} failed"

triggers:
  - id: on_failure
    type: io.kestra.plugin.core.trigger.Flow
    preconditions:
      id: any_failure
      flows:
        - namespace: company.team
          flowId: "*"  # All flows in namespace
          states: [FAILED]
```

## ISO 8601 Duration Format

| Format | Duration |
|--------|----------|
| PT30S | 30 seconds |
| PT5M | 5 minutes |
| PT1H | 1 hour |
| PT1H30M | 1 hour 30 minutes |
| P1D | 1 day |
| P1DT12H | 1 day 12 hours |
