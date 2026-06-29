#!/usr/bin/env bash
# mcp-health.sh — runs ON the Omnistation sandbox.
# Checks all 9 MCP-exposed CLIs and prints a colored ✓/✗ status line.
# Output is cached by omni-banner.sh / omni-statusline.sh on the client.

GRN='\e[38;2;118;185;0m'   # NVIDIA Green
RED='\e[38;2;220;50;50m'
RST='\e[0m'

check() {
    local name="$1" cmd="$2"
    if command -v "$cmd" >/dev/null 2>&1; then
        printf "${GRN}✓${RST} %s  " "$name"
    else
        printf "${RED}✗${RST} %s  " "$name"
    fi
}

check jira       jira-cli
check nvbugs     nvbugs-cli
check slack      slack-cli
check confluence confluence-cli
check outlook    outlook-cli
check nvinfo     nvinfo
check nvspecs    nvspecs-cli
check glean      glean-cli
check meeting    meeting-cli
check onenote    onenote-cli
printf '\n'
