# Common Patterns & Examples

## Table of Contents
1. [ETL Pipeline](#etl-pipeline)
2. [API Data Ingestion](#api-data-ingestion)
3. [Scheduled Report](#scheduled-report)
4. [File Processing](#file-processing)
5. [Notification Workflow](#notification-workflow)
6. [Multi-Environment Deploy](#multi-environment-deploy)
7. [Data Validation](#data-validation)
8. [Batch Processing](#batch-processing)

## ETL Pipeline

```yaml
id: etl-pipeline
namespace: company.data
description: Extract, Transform, Load pipeline

inputs:
  - id: source_table
    type: STRING
    defaults: sales_data
  - id: target_date
    type: DATE
    defaults: "{{ now() | dateAdd(-1, 'DAYS') | date('yyyy-MM-dd') }}"

tasks:
  - id: extract
    type: io.kestra.plugin.scripts.python.Script
    containerImage: python:3.11-slim
    beforeCommands:
      - pip install pandas sqlalchemy psycopg2-binary
    script: |
      import pandas as pd
      from sqlalchemy import create_engine
      
      engine = create_engine("{{ secret('SOURCE_DB_URL') }}")
      df = pd.read_sql("""
        SELECT * FROM {{ inputs.source_table }}
        WHERE date = '{{ inputs.target_date }}'
      """, engine)
      df.to_csv("extracted.csv", index=False)
    outputFiles:
      - "extracted.csv"

  - id: transform
    type: io.kestra.plugin.scripts.python.Script
    containerImage: python:3.11-slim
    beforeCommands:
      - pip install pandas
    inputFiles:
      data.csv: "{{ outputs.extract.outputFiles['extracted.csv'] }}"
    script: |
      import pandas as pd
      from kestra import Kestra
      
      df = pd.read_csv("data.csv")
      
      # Transform
      df['amount'] = df['amount'].fillna(0)
      df['processed_at'] = pd.Timestamp.now()
      
      df.to_csv("transformed.csv", index=False)
      Kestra.outputs({"row_count": len(df)})
    outputFiles:
      - "transformed.csv"

  - id: load
    type: io.kestra.plugin.scripts.python.Script
    containerImage: python:3.11-slim
    beforeCommands:
      - pip install pandas sqlalchemy psycopg2-binary
    inputFiles:
      data.csv: "{{ outputs.transform.outputFiles['transformed.csv'] }}"
    script: |
      import pandas as pd
      from sqlalchemy import create_engine
      
      engine = create_engine("{{ secret('TARGET_DB_URL') }}")
      df = pd.read_csv("data.csv")
      df.to_sql("processed_sales", engine, if_exists="append", index=False)

triggers:
  - id: daily
    type: io.kestra.plugin.core.trigger.Schedule
    cron: "0 2 * * *"  # 2 AM daily

errors:
  - id: alert
    type: io.kestra.plugin.notifications.slack.SlackIncomingWebhook
    url: "{{ secret('SLACK_WEBHOOK') }}"
    messageText: "ETL Pipeline failed: {{ flow.id }}"
```

## API Data Ingestion

```yaml
id: api-ingestion
namespace: company.data

inputs:
  - id: api_endpoint
    type: STRING
    defaults: "https://api.example.com/data"
  - id: page_size
    type: INT
    defaults: 100

tasks:
  - id: fetch_data
    type: io.kestra.plugin.core.http.Request
    uri: "{{ inputs.api_endpoint }}"
    method: GET
    headers:
      Authorization: "Bearer {{ secret('API_TOKEN') }}"
      Content-Type: application/json
    retry:
      type: exponential
      maxAttempts: 3
      interval: PT10S

  - id: check_response
    type: io.kestra.plugin.core.flow.If
    condition: "{{ outputs.fetch_data.code == 200 }}"
    then:
      - id: process_data
        type: io.kestra.plugin.scripts.python.Script
        containerImage: python:3.11-slim
        beforeCommands:
          - pip install pandas kestra
        script: |
          import json
          import pandas as pd
          from kestra import Kestra
          
          data = {{ outputs.fetch_data.body | json }}
          df = pd.DataFrame(data['items'])
          df.to_csv("api_data.csv", index=False)
          
          Kestra.outputs({
            "record_count": len(df),
            "columns": list(df.columns)
          })
        outputFiles:
          - "api_data.csv"
    else:
      - id: log_error
        type: io.kestra.plugin.core.log.Log
        level: ERROR
        message: "API returned {{ outputs.fetch_data.code }}"
```

## Scheduled Report

```yaml
id: weekly-report
namespace: company.reports

tasks:
  - id: generate_report
    type: io.kestra.plugin.scripts.python.Script
    containerImage: python:3.11-slim
    beforeCommands:
      - pip install pandas matplotlib kestra
    script: |
      import pandas as pd
      import matplotlib.pyplot as plt
      from kestra import Kestra
      
      # Generate report data
      data = {"metric": ["Sales", "Users", "Revenue"], "value": [100, 250, 5000]}
      df = pd.DataFrame(data)
      
      # Create chart
      plt.figure(figsize=(10, 6))
      plt.bar(df['metric'], df['value'])
      plt.title("Weekly Metrics")
      plt.savefig("chart.png")
      
      # Save CSV
      df.to_csv("report.csv", index=False)
      
      Kestra.outputs({"generated_at": str(pd.Timestamp.now())})
    outputFiles:
      - "report.csv"
      - "chart.png"

  - id: send_email
    type: io.kestra.plugin.notifications.mail.MailSend
    host: "{{ secret('SMTP_HOST') }}"
    port: 587
    username: "{{ secret('SMTP_USER') }}"
    password: "{{ secret('SMTP_PASS') }}"
    from: reports@company.com
    to: team@company.com
    subject: "Weekly Report - {{ trigger.date | date('yyyy-MM-dd') }}"
    htmlTextContent: |
      <h2>Weekly Report</h2>
      <p>Generated at: {{ outputs.generate_report.vars.generated_at }}</p>
      <p>Please find the attached report.</p>
    attachments:
      - "{{ outputs.generate_report.outputFiles['report.csv'] }}"
      - "{{ outputs.generate_report.outputFiles['chart.png'] }}"

triggers:
  - id: weekly
    type: io.kestra.plugin.core.trigger.Schedule
    cron: "0 8 * * 1"  # Every Monday at 8 AM
```

## File Processing

```yaml
id: file-processor
namespace: company.data

tasks:
  - id: list_files
    type: io.kestra.plugin.scripts.shell.Commands
    commands:
      - |
        files=$(find /data/incoming -name "*.csv" -type f)
        echo "::{"outputs":{"files":$(echo $files | jq -R -s 'split("\n") | map(select(length > 0))')}}::"

  - id: process_files
    type: io.kestra.plugin.core.flow.EachParallel
    value: "{{ outputs.list_files.vars.files }}"
    concurrencyLimit: 3
    tasks:
      - id: process_single
        type: io.kestra.plugin.scripts.python.Script
        containerImage: python:3.11-slim
        beforeCommands:
          - pip install pandas
        script: |
          import pandas as pd
          import os
          
          file_path = "{{ taskrun.value }}"
          df = pd.read_csv(file_path)
          
          # Process
          df['processed'] = True
          
          # Save to output
          output_name = os.path.basename(file_path).replace('.csv', '_processed.csv')
          df.to_csv(output_name, index=False)
        outputFiles:
          - "*_processed.csv"
```

## Notification Workflow

```yaml
id: alert-manager
namespace: company.monitoring

inputs:
  - id: alert_type
    type: SELECT
    values: [critical, warning, info]
    defaults: info
  - id: message
    type: STRING
    required: true

tasks:
  - id: route_alert
    type: io.kestra.plugin.core.flow.Switch
    value: "{{ inputs.alert_type }}"
    cases:
      critical:
        - id: page_oncall
          type: io.kestra.plugin.notifications.slack.SlackIncomingWebhook
          url: "{{ secret('SLACK_ONCALL_WEBHOOK') }}"
          messageText: "🚨 CRITICAL: {{ inputs.message }}"
        - id: send_sms
          type: io.kestra.plugin.core.http.Request
          uri: "{{ secret('SMS_API_URL') }}"
          method: POST
          body: |
            {"to": "{{ secret('ONCALL_PHONE') }}", "message": "{{ inputs.message }}"}
      warning:
        - id: slack_warning
          type: io.kestra.plugin.notifications.slack.SlackIncomingWebhook
          url: "{{ secret('SLACK_ALERTS_WEBHOOK') }}"
          messageText: "⚠️ WARNING: {{ inputs.message }}"
      info:
        - id: slack_info
          type: io.kestra.plugin.notifications.slack.SlackIncomingWebhook
          url: "{{ secret('SLACK_INFO_WEBHOOK') }}"
          messageText: "ℹ️ INFO: {{ inputs.message }}"
```

## Multi-Environment Deploy

```yaml
id: deploy-service
namespace: company.devops

inputs:
  - id: environment
    type: SELECT
    values: [dev, staging, prod]
    required: true
  - id: version
    type: STRING
    required: true

tasks:
  - id: validate
    type: io.kestra.plugin.core.flow.If
    condition: "{{ inputs.environment == 'prod' }}"
    then:
      - id: prod_approval
        type: io.kestra.plugin.core.flow.Pause
        timeout: PT1H
        description: "Approve production deployment of v{{ inputs.version }}"

  - id: deploy
    type: io.kestra.plugin.scripts.shell.Commands
    taskRunner:
      type: io.kestra.plugin.scripts.runner.docker.Docker
      containerImage: bitnami/kubectl:latest
    commands:
      - |
        kubectl config use-context {{ inputs.environment }}-cluster
        kubectl set image deployment/myapp myapp=myregistry/myapp:{{ inputs.version }}
        kubectl rollout status deployment/myapp --timeout=300s

  - id: notify
    type: io.kestra.plugin.notifications.slack.SlackIncomingWebhook
    url: "{{ secret('SLACK_DEPLOYS_WEBHOOK') }}"
    messageText: |
      ✅ Deployed v{{ inputs.version }} to {{ inputs.environment }}
      Executed by: {{ execution.id }}
```

## Data Validation

```yaml
id: data-quality-check
namespace: company.data

inputs:
  - id: table_name
    type: STRING
    required: true

tasks:
  - id: run_checks
    type: io.kestra.plugin.scripts.python.Script
    containerImage: python:3.11-slim
    beforeCommands:
      - pip install pandas sqlalchemy psycopg2-binary kestra
    script: |
      import pandas as pd
      from sqlalchemy import create_engine
      from kestra import Kestra
      
      engine = create_engine("{{ secret('DB_URL') }}")
      
      checks = []
      
      # Check 1: Row count
      count = pd.read_sql("SELECT COUNT(*) as cnt FROM {{ inputs.table_name }}", engine)['cnt'][0]
      checks.append({"check": "row_count", "value": int(count), "passed": count > 0})
      
      # Check 2: Null check
      nulls = pd.read_sql("""
        SELECT COUNT(*) as cnt FROM {{ inputs.table_name }} 
        WHERE id IS NULL
      """, engine)['cnt'][0]
      checks.append({"check": "no_null_ids", "value": int(nulls), "passed": nulls == 0})
      
      # Check 3: Duplicates
      dupes = pd.read_sql("""
        SELECT COUNT(*) - COUNT(DISTINCT id) as cnt FROM {{ inputs.table_name }}
      """, engine)['cnt'][0]
      checks.append({"check": "no_duplicates", "value": int(dupes), "passed": dupes == 0})
      
      all_passed = all(c['passed'] for c in checks)
      Kestra.outputs({"checks": checks, "all_passed": all_passed})

  - id: fail_if_invalid
    type: io.kestra.plugin.core.execution.Fail
    condition: "{{ outputs.run_checks.vars.all_passed == false }}"
    message: "Data quality checks failed"
```

## Batch Processing

```yaml
id: batch-processor
namespace: company.data

tasks:
  - id: get_batches
    type: io.kestra.plugin.jdbc.postgresql.Query
    url: "{{ secret('DB_URL') }}"
    sql: |
      SELECT DISTINCT batch_id FROM pending_jobs 
      WHERE status = 'pending'
      LIMIT 100
    store: true

  - id: process_batches
    type: io.kestra.plugin.core.flow.ForEachItem
    items: "{{ outputs.get_batches.uri }}"
    batch:
      rows: 10
    namespace: company.data
    flowId: process-single-batch
    inputs:
      batch_ids: "{{ taskrun.items }}"
    wait: true
    transmitFailed: true
    concurrencyLimit: 5

  - id: summary
    type: io.kestra.plugin.core.log.Log
    message: "Processed {{ outputs.get_batches.size }} batches"
```
