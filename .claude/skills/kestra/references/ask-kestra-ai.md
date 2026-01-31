# Ask Kestra AI

Use this skill to query the Kestra AI documentation assistant for technical questions about Kestra workflows, tasks, plugins, and best practices.

## When to Use

- When you need accurate Kestra-specific documentation
- For questions about task configuration, outputs, inputs
- To understand Kestra plugin behavior
- When the local `generate_flow` MCP tool fails or gives incomplete answers

## API Endpoint

```
POST https://api.kestra.io/v1/search-ai/{session_id}
Content-Type: application/json
```

## Request Format

```json
{
  "messages": [
    {"role": "user", "content": "Your question here"}
  ]
}
```

- `session_id`: Any unique string to identify your session (e.g., `claude_session_001`)
- `messages`: Array of message objects with `role` and `content`

## Response Format

The API returns a streaming response with Server-Sent Events (SSE):

```
id: response
data: {"type":"response","response":"partial answer text..."}

id: response
data: {"type":"response","response":"more text..."}

id: usage
data: {"type":"usage","inputTokens":14407,"outputTokens":508,"totalTokens":15428}

id: completed
data: {"type":"completed"}
```

## Example Usage

### Simple Query

```bash
curl -s "https://api.kestra.io/v1/search-ai/my_session" \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user", "content": "How do I pass taskrun.items to a subflow FILE input?"}]}'
```

### Parse Response (extract full answer)

```bash
curl -s "https://api.kestra.io/v1/search-ai/session_001" \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user", "content": "Your question"}]}' \
  | grep 'data:' \
  | sed 's/^data: //' \
  | jq -s '[.[] | select(.type == "response")] | .[].response' -r \
  | tr -d '\n' \
  | fold -s -w 120
```

## Multi-turn Conversations

For follow-up questions, include previous messages:

```json
{
  "messages": [
    {"role": "user", "content": "What is ForEachItem?"},
    {"role": "assistant", "content": "ForEachItem is a task that..."},
    {"role": "user", "content": "How do I access its outputs?"}
  ]
}
```

## Tips

1. **Be specific**: Include task names, property names, and context
2. **Use session IDs**: Different session IDs start fresh conversations
3. **Check for updates**: The AI has access to current Kestra documentation
4. **Verify answers**: Cross-reference with official docs when possible

## Common Questions to Ask

- "How do I pass taskrun.items to a subflow FILE input?"
- "What is the structure of ForEachItem outputs?"
- "How do I merge FILE outputs from ForEachItem subflows?"
- "What is ForEachItemMergeOutputs and how does subflowOutputs work?"
- "How do I read data from an ION file in a Kestra expression?"
