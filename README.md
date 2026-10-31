# portal

A local Hermes-to-Kilo bridge is available through `kilo_mcp_server.py`.

Hermes can call the `kilo_run` MCP tool to delegate a coding task to the locally installed Kilo CLI. The bridge runs in the current workspace and forwards an optional `model` value to Kilo.

Register it with:

```bash
hermes mcp add kilo --command python3 --args /workspaces/portal/kilo_mcp_server.py
```

Then verify it with:

```bash
hermes mcp list
hermes mcp test kilo
```

The bridge uses Kilo's `--auto` mode so Kilo can complete terminal and workspace tasks without interactive permission prompts.
