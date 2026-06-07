#!/bin/bash
# statusLine command — colorized sandbox + MCP status for Claude Code footer
CACHE="$HOME/.omni-mcp-status"

R='\e[0m'           # reset
BOLD='\e[1m'
DIM='\e[2m'
NV='\e[38;2;118;185;0m'   # NVIDIA Green #76B900
RED='\e[38;2;220;50;50m'
CYAN='\e[38;2;100;200;240m'
GRAY='\e[38;2;150;150;150m'

NAME="omni-lsn-talxl"

if [[ -f "$CACHE" ]]; then
    # Cache has ANSI ✓/✗ colors from mcp-health.sh — preserve them
    mcp=$(cat "$CACHE" 2>/dev/null | tr -d '\n')
    status="${BOLD}${NV}● RUNNING${R}"
else
    mcp="${RED}no cache — run: ssh omnistation '~/mcp-health.sh' > ~/.omni-mcp-status${R}"
    status="${RED}● UNKNOWN${R}"
fi

printf "${GRAY}omnistation${R} ${BOLD}${CYAN}${NAME}${R}  ${status}  ${GRAY}│  MCP:${R} ${mcp}${R}\n"
