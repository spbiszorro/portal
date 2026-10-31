#!/usr/bin/env python3
import json
import os
import subprocess
import sys


def response(request_id, result=None, error=None):
    message = {"jsonrpc": "2.0", "id": request_id}
    if error is not None:
        message["error"] = error
    else:
        message["result"] = result
    return message


def run_kilo(arguments):
    prompt = arguments.get("prompt")
    if not isinstance(prompt, str) or not prompt.strip():
        return {"isError": True, "content": [{"type": "text", "text": "prompt is required"}]}

    command = [
        os.path.expanduser("~/.kilo/bin/kilo"),
        "run",
        "--format",
        "json",
        "--auto",
        prompt.strip(),
    ]
    if arguments.get("model"):
        command.extend(["--model", str(arguments["model"])])

    try:
        completed = subprocess.run(
            command,
            cwd=os.getcwd(),
            text=True,
            capture_output=True,
            timeout=600,
            check=False,
        )
        output = completed.stdout.strip()
        if completed.stderr.strip():
            output = "{}\n{}".format(output, completed.stderr.strip()).strip()
        if completed.returncode != 0:
            return {"isError": True, "content": [{"type": "text", "text": output or "Kilo exited without output"}]}
        return {"content": [{"type": "text", "text": output or "Kilo completed without output"}]}
    except subprocess.TimeoutExpired:
        return {"isError": True, "content": [{"type": "text", "text": "Kilo task timed out after 600 seconds"}]}
    except FileNotFoundError:
        return {"isError": True, "content": [{"type": "text", "text": "Kilo executable was not found"}]}


def handle(request):
    method = request.get("method")
    request_id = request.get("id")

    if method == "initialize":
        return response(request_id, {
            "protocolVersion": request.get("params", {}).get("protocolVersion", "2024-11-05"),
            "capabilities": {"tools": {"listChanged": False}},
            "serverInfo": {"name": "kilo-mcp", "version": "1.0.0"},
        })
    if method == "notifications/initialized":
        return None
    if method == "ping":
        return response(request_id, {})
    if method == "tools/list":
        return response(request_id, {"tools": [{
            "name": "kilo_run",
            "description": "Delegate a software engineering task to the local Kilo terminal coding agent.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "prompt": {"type": "string", "description": "The task for Kilo to perform."},
                    "model": {"type": "string", "description": "Optional Kilo model in provider/model format."},
                },
                "required": ["prompt"],
            },
        }]})
    if method == "tools/call":
        params = request.get("params", {})
        if params.get("name") != "kilo_run":
            return response(request_id, error={"code": -32602, "message": "Unknown tool"})
        return response(request_id, run_kilo(params.get("arguments", {})))
    if request_id is not None:
        return response(request_id, error={"code": -32601, "message": "Method not found"})
    return None


def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            request = json.loads(line)
            result = handle(request)
            if result is not None:
                sys.stdout.write(json.dumps(result) + "\n")
                sys.stdout.flush()
        except Exception as exc:
            sys.stderr.write("kilo_mcp_server: {}\n".format(exc))


if __name__ == "__main__":
    main()
