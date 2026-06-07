#!/usr/bin/env python3
"""MCP server exposing NVIDIA Omnistation company CLIs as tools."""

import asyncio
import json
import subprocess
from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp import types

app = Server("omnistation")

_TOOLS = [
    types.Tool(
        name="jira",
        description="Query NVIDIA Jira (jirasw.nvidia.com). Get issues, search, list projects/boards/sprints. Use --toon for LLM-friendly output.",
        inputSchema={
            "type": "object",
            "properties": {
                "args": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "jira-cli arguments, e.g. ['issue', 'get', 'NV-1234', '--toon'] or ['issue', 'find', '--query', 'project=FOO', '--toon']",
                }
            },
            "required": ["args"],
        },
    ),
    types.Tool(
        name="nvbugs",
        description="Query NVIDIA NVBugs internal bug tracker. Get bug details, search, list attachments/comments.",
        inputSchema={
            "type": "object",
            "properties": {
                "args": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "nvbugs-cli arguments, e.g. ['get', '12345'] or ['search', '--synopsis', 'cuda memory leak']",
                }
            },
            "required": ["args"],
        },
    ),
    types.Tool(
        name="slack",
        description="Read Slack messages, search history, look up users and DMs (read-only).",
        inputSchema={
            "type": "object",
            "properties": {
                "args": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "slack-cli arguments, e.g. ['search', '--query', 'cuda regression'] or ['user', 'lookup', '--email', 'foo@nvidia.com']",
                }
            },
            "required": ["args"],
        },
    ),
    types.Tool(
        name="confluence",
        description="Search and read NVIDIA Confluence pages and spaces.",
        inputSchema={
            "type": "object",
            "properties": {
                "args": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "confluence-cli arguments, e.g. ['search', '--query', 'onboarding guide'] or ['page', 'get', '--id', '12345']",
                }
            },
            "required": ["args"],
        },
    ),
    types.Tool(
        name="outlook",
        description="Read NVIDIA Outlook email (inbox, search, read threads).",
        inputSchema={
            "type": "object",
            "properties": {
                "args": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "outlook-cli arguments, e.g. ['inbox', '--limit', '10'] or ['search', '--query', 'project review']",
                }
            },
            "required": ["args"],
        },
    ),
    types.Tool(
        name="nvinfo",
        description="Look up NVIDIA employee info, org charts, team members by name or email.",
        inputSchema={
            "type": "object",
            "properties": {
                "args": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "nvinfo arguments, e.g. ['subansal'] or ['--email', 'foo@nvidia.com']",
                }
            },
            "required": ["args"],
        },
    ),
    types.Tool(
        name="nvspecs",
        description="Query NVIDIA hardware/product specs database.",
        inputSchema={
            "type": "object",
            "properties": {
                "args": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "nvspecs-cli arguments",
                }
            },
            "required": ["args"],
        },
    ),
    types.Tool(
        name="glean",
        description="Search across all NVIDIA internal knowledge (Glean enterprise search).",
        inputSchema={
            "type": "object",
            "properties": {
                "args": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "glean-cli arguments, e.g. ['search', '--query', 'cuda driver release notes']",
                }
            },
            "required": ["args"],
        },
    ),
    types.Tool(
        name="meeting",
        description="Access Teams meeting transcripts, attendance, and AI recaps.",
        inputSchema={
            "type": "object",
            "properties": {
                "args": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "meeting-cli arguments, e.g. ['list'] or ['transcript', '--id', 'abc123']",
                }
            },
            "required": ["args"],
        },
    ),
    types.Tool(
        name="onenote",
        description="Read and search Microsoft OneNote notebooks.",
        inputSchema={
            "type": "object",
            "properties": {
                "args": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "onenote-cli arguments, e.g. ['search', '--query', 'project notes']",
                }
            },
            "required": ["args"],
        },
    ),
    types.Tool(
        name="omni_shell",
        description="Run an arbitrary shell command on the Omnistation sandbox. Use for ad-hoc access to any other company tool or file. Prefer specific tools above when available.",
        inputSchema={
            "type": "object",
            "properties": {
                "command": {
                    "type": "string",
                    "description": "Shell command to run, e.g. 'transcript-cli list --limit 5'",
                }
            },
            "required": ["command"],
        },
    ),
]

_CLI_MAP = {
    "jira": "jira-cli",
    "nvbugs": "nvbugs-cli",
    "slack": "slack-cli",
    "confluence": "confluence-cli",
    "outlook": "outlook-cli",
    "nvinfo": "nvinfo",
    "nvspecs": "nvspecs-cli",
    "glean": "glean-cli",
    "meeting": "meeting-cli",
    "onenote": "onenote-cli",
}


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
    if name == "omni_shell":
        output = _run(["bash", "-c", arguments["command"]], timeout=120)
    elif name in _CLI_MAP:
        output = _run([_CLI_MAP[name]] + arguments["args"])
    else:
        output = f"[unknown tool: {name}]"

    return [types.TextContent(type="text", text=output)]


async def main():
    async with stdio_server() as (read_stream, write_stream):
        await app.run(read_stream, write_stream, app.create_initialization_options())


if __name__ == "__main__":
    asyncio.run(main())
