# Kestra Gotchas & Hard-Won Lessons

Common pitfalls that are not obvious from the documentation and can cause hours of debugging.

## Table of Contents
1. [kestra:/// URI Auto-Resolution](#kestra-uri-auto-resolution)
2. [ForEachItem Merge Output Access](#foreachitem-merge-output-access)
3. [Debugging with printContext()](#debugging-with-printcontext)
4. [read() Function for URI Content](#read-function-for-uri-content)
5. [replace() Filter to Strip URI Prefixes](#replace-filter-to-strip-uri-prefixes)
6. [Process TaskRunner Filesystem Access](#process-taskrunner-filesystem-access)
7. [inputFiles for Shell Quoting Safety](#inputfiles-for-shell-quoting-safety)
8. [Literal kestra:/// in Shell Commands](#literal-kestra-in-shell-commands)
9. [JSON Body Interpolation with | json Filter](#json-body-interpolation-with--json-filter)
10. [Restart vs Replay Execution](#restart-vs-replay-execution)

---

## kestra:/// URI Auto-Resolution

**Problem:** Kestra's Pebble renderer automatically resolves ANY `kestra:///` URI found in YAML property values — including `inputFiles`, `env`, and `commands`. If the URI is embedded inside content (e.g., an ION file containing multiple URIs as text), Kestra tries to resolve the parent path and fails with:

```
java.io.FileNotFoundException: /app/storage/main (Is a directory)
```

**Why it happens:** Kestra scans all rendered property values for `kestra:///` patterns and attempts to resolve them as internal storage file references before the task executes. This happens at the template rendering phase, not at runtime.

**Affected properties:**
- `inputFiles` values
- `env` values
- `commands` block content
- Any string property rendered by Pebble

**Workaround:** Strip the `kestra:///` prefix using Pebble's `replace()` filter before passing to tasks:

```yaml
- id: strip_prefix
  type: io.kestra.plugin.core.output.OutputValues
  values:
    cleanPath: "{{ someUri | replace({'kestra:///': ''}) }}"
```

Then reference as a filesystem path: `/app/storage/main/{{ outputs.strip_prefix.values.cleanPath }}`.

---

## ForEachItem Merge Output Access

**Problem:** ForEachItem creates internal subtasks with a naming convention that isn't documented. Accessing subflow outputs requires knowing these internal task IDs.

**Internal subtask naming:** For a ForEachItem task with `id: for_each_company`, Kestra creates:
- `for_each_company_split` — splits input items into batches
- `for_each_company_items` — runs the subflow for each batch
- `for_each_company_merge` — merges subflow outputs

**Accessing merged outputs:**
```yaml
{{ outputs.for_each_company_merge.subflowOutputs }}
```

This returns a `kestra:///` URI pointing to an ION file. Each line of the ION file contains one subflow's output references:

```ion
{outputName:"kestra:///namespace/flow/executions/.../result.ndjson"}
{outputName:"kestra:///namespace/flow/executions/.../result.ndjson"}
```

**Key insight:** `subflowOutputs` is NOT the actual data — it's a URI to a metadata file containing more URIs.

---

## Debugging with printContext()

**Problem:** You don't know what variables, outputs, or expressions are available at a given point in the flow.

**Solution:** Add a temporary Log task with `{{ printContext() }}`:

```yaml
- id: debug_context
  type: io.kestra.plugin.core.log.Log
  message: "{{ printContext() }}"
```

This dumps ALL available variables including:
- `inputs.*`
- `outputs.*` (all completed tasks)
- `vars.*`
- `taskrun.*`
- `flow.*`
- `execution.*`

**Best practice:** Add this temporarily, run once, check the execution logs, then remove it.

---

## read() Function for URI Content

**Problem:** You have a `kestra:///` URI and need its content as a string in a Pebble expression.

**Solution:** Use the `read()` function:

```yaml
{{ read(outputs.someTask.uri) }}
```

This reads the file content at the given `kestra:///` URI and returns it as a string. Useful for:
- Reading ION/JSON files inline
- Passing file content to expressions
- Inspecting internal storage files in log messages

**Example — reading merged subflow outputs:**
```yaml
- id: log_merge_content
  type: io.kestra.plugin.core.log.Log
  message: "{{ read(outputs.for_each_company_merge.subflowOutputs) }}"
```

---

## replace() Filter to Strip URI Prefixes

**Problem:** You need to convert a `kestra:///` URI to a filesystem path without triggering auto-resolution.

**Solution:** Use `replace()` in a separate OutputValues task:

```yaml
- id: extract_path
  type: io.kestra.plugin.core.output.OutputValues
  values:
    storagePath: "/app/storage/main/{{ someKestraUri | replace({'kestra:///': ''}) }}"
```

**Why a separate task?** If you inline the `replace()` in an `env` or `inputFiles` property, Kestra may still detect and attempt to resolve the original URI before the filter runs. Using an intermediate OutputValues task ensures the stripped path is stored as a plain string.

---

## Process TaskRunner Filesystem Access

**Problem:** You need to access Kestra's internal storage files directly from a shell task.

**Solution:** When using `type: io.kestra.plugin.core.runner.Process`, the task runs directly on the Kestra container. Internal storage is accessible at:

```
/app/storage/main/<namespace>/<flow-id-kebab>/executions/<exec-id>/tasks/<task-id-kebab>/<taskrun-id>/<filename>
```

**Example — reading subflow output files directly:**
```yaml
- id: merge_results
  type: io.kestra.plugin.scripts.shell.Commands
  taskRunner:
    type: io.kestra.plugin.core.runner.Process
  env:
    STORAGE_PATH: "{{ outputs.extract_path.values.storagePath }}"
  commands:
    - cat "$STORAGE_PATH"
```

**Note:** This only works with the `Process` taskRunner. Docker or Kubernetes runners don't have access to the host filesystem.

---

## inputFiles for Shell Quoting Safety

**Problem:** Passing API responses or JSON content directly in shell commands causes quoting issues — single quotes, double quotes, backticks, dollar signs, and other special characters in the content break the shell.

**Bad — direct interpolation:**
```yaml
commands:
  - echo '{{ outputs.api_call.body }}' > result.json  # BREAKS with quotes in body
```

**Good — use inputFiles:**
```yaml
- id: process_response
  type: io.kestra.plugin.scripts.shell.Commands
  taskRunner:
    type: io.kestra.plugin.core.runner.Process
  inputFiles:
    result.json: '{{ outputs.api_call.body }}'
  commands:
    - cat result.json  # File is already written safely
  outputFiles:
    - result.json
```

`inputFiles` writes the content to a file before the shell commands run, bypassing all shell quoting issues.

---

## Literal kestra:/// in Shell Commands

**Problem:** If the string `kestra:///` appears literally anywhere in the YAML — even inside shell script strings like `sed` patterns or `grep` expressions — Kestra's renderer will try to resolve it as a file URI.

**Bad — literal kestra:/// in sed pattern:**
```yaml
commands:
  - sed 's|kestra:///||g' input.txt  # Kestra tries to resolve this!
```

**Good — build the string dynamically in shell:**
```yaml
commands:
  - |
    PROTO="kestra"
    PROTO="${PROTO}://"
    sed "s|${PROTO}/||g" input.txt
```

This avoids the literal `kestra:///` string in the YAML while producing the same shell behavior at runtime.

---

## JSON Body Interpolation with | json Filter

**Problem:** When building JSON request bodies in HTTP Request tasks, interpolating user-supplied strings with `"{{ value }}"` breaks if the value contains double quotes, backslashes, or other JSON-special characters.

**Example failure:** A company name like `SILVICULTURA "MARIN DRACEA"` produces invalid JSON:
```json
{"Name": "SILVICULTURA "MARIN DRACEA""}  // Broken!
```

**Bad — direct string interpolation:**
```yaml
body: |
  {
    "Name": "{{ outputs.extract_fields.values.companyName }}"
  }
```

**Good — use the `| json` filter:**
```yaml
body: |
  {
    "Name": {{ outputs.extract_fields.values.companyName | json }}
  }
```

The `| json` filter outputs a properly escaped JSON string **including the surrounding quotes**: `"SILVICULTURA \"MARIN DRACEA\""`. Do NOT add your own quotes around it.

**String concatenation before escaping:** Use the `~` operator to concatenate before applying `| json`:
```yaml
# Append a wildcard then JSON-escape the whole string
"NameDirect": [{{ (outputs.extract_fields.values.fullname ~ "*") | json }}]
```

**Rule of thumb:** Always use `{{ value | json }}` (without surrounding quotes) when interpolating any user-supplied or external data into a JSON body. This applies to HTTP Request bodies, webhook payloads, and any other JSON construction in Pebble templates.

---

## Restart vs Replay Execution

**Problem:** After fixing a flow and deploying a new revision, restarting a failed execution still fails because `restart_execution` replays using the **original flow revision**, not the latest.

**Why:** Kestra's restart is designed for transient failures (network timeouts, rate limits) — it re-runs the same flow definition to ensure reproducibility.

**Solution:** Use `replay_execution` with `latest_revision: true` to test a fix against an existing execution's inputs:

```
# Via MCP
replay_execution(ids=["<execution_id>"], latest_revision=true)

# Via API
POST /api/v1/executions/replay/by/execution_id/<execution_id>?revision=latest
```

**When to use which:**
| Scenario | Use |
|----------|-----|
| Transient failure (timeout, rate limit) | `restart_execution` |
| Fixed a bug in the flow YAML | `replay_execution` with `latest_revision: true` |
| Need to re-run with different inputs | Create a new execution |
