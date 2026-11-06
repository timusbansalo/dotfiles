#!/usr/bin/env python3
"""MCP server exposing a shell + file tools on subansal-prod-vm2."""

import asyncio
import os
import subprocess
from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp import types

app = Server("prodvm2")

_TOOLS = [
    types.Tool(
        name="shell",
        description="Run an arbitrary shell command on subansal-prod-vm2. Returns stdout/stderr. Prefer specific tools when available.",
        inputSchema={
            "type": "object",
            "properties": {
                "command": {
                    "type": "string",
                    "description": "Shell command to run, e.g. 'ls ~/src' or 'docker ps'",
                }
            },
            "required": ["command"],
        },
    ),
    types.Tool(
        name="read_file",
        description="Read the contents of a file on subansal-prod-vm2.",
        inputSchema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Absolute or ~-relative file path, e.g. '~/src/app/main.py'",
                }
            },
            "required": ["path"],
        },
    ),
    types.Tool(
        name="write_file",
        description="Write content to a file on subansal-prod-vm2 (overwrites if exists).",
        inputSchema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Absolute or ~-relative file path",
                },
                "content": {
                    "type": "string",
                    "description": "File content to write",
                },
            },
            "required": ["path", "content"],
        },
    ),
    types.Tool(
        name="list_dir",
        description="List files in a directory on subansal-prod-vm2.",
        inputSchema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Directory path, e.g. '~' or '~/src'",
                }
            },
            "required": ["path"],
        },
    ),
]


def _run(cmd: list[str], timeout: int = 60) -> str:
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        out = result.stdout.strip()
        err = result.stderr.strip()
        if result.returncode != 0:
            return f"[exit {result.returncode}]\n{err or out}"
        return out or err or "(no output)"
    except subprocess.TimeoutExpired:
        return f"[timeout after {timeout}s]"
    except Exception as e:
        return f"[error: {e}]"


@app.list_tools()
async def list_tools() -> list[types.Tool]:
    return _TOOLS


@app.call_tool()
async def call_tool(name: str, arguments: dict) -> list[types.TextContent]:
    if name == "shell":
        output = _run(["bash", "-c", arguments["command"]], timeout=120)
    elif name == "read_file":
        path = os.path.expanduser(arguments["path"])
        output = _run(["cat", path])
    elif name == "write_file":
        path = os.path.expanduser(arguments["path"])
        try:
            os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
            with open(path, "w") as f:
                f.write(arguments["content"])
            output = f"wrote {path}"
        except Exception as e:
            output = f"[error: {e}]"
    elif name == "list_dir":
        path = os.path.expanduser(arguments["path"])
        output = _run(["ls", "-la", path])
    else:
        output = f"[unknown tool: {name}]"

    return [types.TextContent(type="text", text=output)]


async def main():
    async with stdio_server() as (read_stream, write_stream):
        await app.run(read_stream, write_stream, app.create_initialization_options())


if __name__ == "__main__":
    asyncio.run(main())
