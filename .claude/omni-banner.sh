#!/bin/bash
# SessionStart hook — emits a welcome banner with sandbox + MCP status
# Output: JSON {"systemMessage": "..."} consumed by Claude Code

CACHE="$HOME/.omni-mcp-status"

strip_ansi() { sed 's/\x1b\[[0-9;]*m//g'; }

if [[ -f "$CACHE" ]]; then
    mcp=$(cat "$CACHE" 2>/dev/null | strip_ansi | tr -d '\n')
    age=$(( $(date +%s) - $(stat -c %Y "$CACHE" 2>/dev/null || stat -f %m "$CACHE" 2>/dev/null || echo 0) ))
    [[ $age -gt 300 ]] && (ssh -o ConnectTimeout=5 -o BatchMode=yes omnistation '~/mcp-health.sh' > "$CACHE" 2>/dev/null &)
else
    mcp="(not cached yet)"
    (ssh -o ConnectTimeout=5 -o BatchMode=yes omnistation '~/mcp-health.sh' > "$CACHE" 2>/dev/null &)
fi

DATE=$(date '+%a %b %-d, %Y  %H:%M')
DIR=$(pwd)

python3 - <<PYEOF
import json

mcp  = """$mcp""".strip()
date = """$DATE"""
cwd  = """$DIR"""

W = 70  # inner width (between "║  " and "  ║")

def row(s):
    # Truncate if too long, then pad to W chars
    s = s[:W]
    return "║  " + s + " " * (W - len(s)) + "  ║"

div = "╠" + "═" * (W + 4) + "╣"
top = "╔" + "═" * (W + 4) + "╗"
bot = "╚" + "═" * (W + 4) + "╝"

# Split MCP tools across two rows if needed
tools = mcp.split()
mid   = len(tools) // 2
row1  = "  ".join(tools[:mid])   if tools else "(no cache)"
row2  = "  ".join(tools[mid:])   if tools else ""

lines = [
    "",
    top,
    row("  CLAUDE CODE  ·  NVIDIA WORKSPACE  ·  Sumit Bansal"),
    div,
    row("  " + date),
    row("  dir: " + cwd),
    div,
    row("  Sandbox  :  omni-lsn-talxl  (codex-sandbox)  ·  RUNNING"),
    row("  MCP      :  " + row1),
]
if row2:
    lines.append(row("             " + row2))
lines += [bot, ""]

print(json.dumps({"systemMessage": "\n".join(lines)}))
PYEOF
