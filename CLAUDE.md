# Kestra Workflows - Claude Code Instructions

## Project Namespace

**Namespace:** `TODO` — define when creating the first flow.

> When creating the first workflow, ask the user for the project namespace.
> Use it for all flows, filenames, storage paths, and subflow references.

## Quick Start

Before starting Claude Code, run:
```bash
./start.sh
```

This ensures Kestra is running so the MCP server can connect.

## Project Structure

```
project-root/
├── CLAUDE.md                              # Claude Code instructions (this file)
├── .mcp.json                              # Kestra MCP server config
├── .env.example                           # Environment variable template
├── .env                                   # Actual env vars (gitignored)
├── .gitignore
├── start.sh                               # Docker startup script
├── docker-compose.yml                     # Kestra + Postgres
├── data/                                  # Shared input/output volume (gitignored)
├── documents/                             # Reference docs (gitignored)
├── flows/                                 # Flow YAML definitions (auto-synced)
│   └── main_<namespace>_<flow_id>.yml     # Naming convention
└── storage/                               # Kestra internal storage (persisted)
    └── main/
        └── <namespace>/
            ├── _files/                    # Shared Python/scripts for all flows
            └── <flow-id-kebab>/
                └── executions/
```

## Flow File Naming Convention

Pattern: `main_<namespace>_<flow_id>.yml`

Examples (assuming namespace `myproject`):

| File | Namespace | Flow ID |
|------|-----------|---------|
| `main_myproject_ingest_data.yml` | `myproject` | `ingest_data` |
| `main_myproject_process_batch.yml` | `myproject` | `process_batch` |

The flow `id` inside the YAML must match the filename suffix.

## Python / Business Logic

Shared code lives in `storage/main/<namespace>/_files/` (Kestra "namespace files").

Access in flows:
```yaml
tasks:
  - id: my_task
    type: io.kestra.plugin.scripts.python.Commands
    namespaceFiles:
      enabled: true    # Makes _files/ available in the working directory
    taskRunner:
      type: io.kestra.plugin.core.runner.Process
    commands:
      - pip install -r requirements.txt
      - python my_script.py
```

## `/data` Shared Volume

- Docker mount: `./data:/data`
- Purpose: input files (Excel, CSV) and output files that persist across executions
- Referenced in flow inputs as `/data/filename.xlsx`
- Gitignored — data stays local

## MCP Server

This project uses the Kestra MCP server for direct workflow management. Config in `.mcp.json`.

**Requirements:**
- Docker must be running
- Kestra containers must be up (`docker-compose up -d`)

**If MCP fails to connect:**
1. Check Kestra is running: `docker-compose ps`
2. Start if needed: `docker-compose up -d`
3. Restart Claude Code

## Kestra Access

- **URL:** http://localhost:8080
- **Username:** admin@kestra.io
- **Password:** Kestra2024

## Environment Variables

Copy `.env.example` to `.env` and configure your variables.

### How environment variables work

In `docker-compose.yml`, add custom env vars:
```yaml
environment:
  ENV_my_api_token: ${MY_API_TOKEN}
  ENV_my_other_var: ${MY_OTHER_VAR:-default_value}
```

In flows, access via Pebble templates:
```yaml
body: "{{ envs.my_api_token }}"
```

Pattern: `ENV_<name>` in compose → `{{ envs.<name> }}` in flows.

## Flow Auto-Sync

Flows in `flows/` auto-sync to Kestra via Micronaut file watcher.

**Caveat:** Sync can lag. When iterating fast, push updates directly via API:
```bash
curl -u "admin@kestra.io:Kestra2024" -X PUT \
  "http://localhost:8080/api/v1/flows/<namespace>/<flow_id>" \
  -H "Content-Type: application/x-yaml" -d "<yaml_content>"
```

Or use the MCP `create_flow_from_yaml` tool.

## Restart vs Replay Executions

- **Restart** re-runs with the **original flow revision** — use for transient failures (timeouts, rate limits)
- **Replay** with `latest_revision: true` uses the **latest flow revision** — use after deploying a bug fix


## Debugging Tips

- **Check task outputs**: In Kestra UI, go to Execution > Outputs tab to see the actual data structure
- **Print all variables**: Add a Log task with `message: "{{ printContext() }}"` to see available variables
- **Test API manually**: `curl -u "admin@kestra.io:Kestra2024" http://localhost:8080/api/v1/flows`
- **Check MCP status**: Run `/mcp` in Claude Code to verify connection
- **Docker logs**: `docker logs <project>-kestra-1` for detailed Kestra error messages

## Ask Kestra AI

For technical questions about Kestra, query the Kestra AI documentation assistant:

```bash
curl -s "https://api.kestra.io/v1/search-ai/session_id" \
  -X POST -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user", "content": "Your question"}]}'
```
