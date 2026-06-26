#!/usr/bin/env bash
# approval-banner.sh — PINK "approval needed" banner for Claude Code.
#
# Fires on the permission_prompt Notification hook (Claude wants to run/edit
# something and needs you to approve). Counterpart to input-banner.sh:
#     PINK  = Claude wants you to APPROVE an action   (this script)
#     CYAN  = Claude is done, your turn to READ + reply   (input-banner.sh)
#     plain = normal log lines (no banner)
#
# Interior text is ASCII-only on purpose (multibyte glyphs miscount column
# width in non-UTF-8 locales). Must be invoked with `> /dev/tty` in
# settings.json or Claude Code captures stdout and you never see it.

set -u

BORDER=$'\033[38;2;244;114;182m'      # bright pink
TITLEBG=$'\033[48;2;190;24;93m'       # deep magenta background
TITLEFG=$'\033[1;38;2;253;242;248m'   # near-white bold
BODY=$'\033[38;2;249;168;212m'        # soft pink
RESET=$'\033[0m'

W=60   # interior width, in columns, between the two border bars

# center $1 inside W columns using ASCII spaces only
pad() {
  local s="$1" len=${#1} left right
  if (( len > W )); then s="${s:0:W}"; len=$W; fi
  left=$(( (W - len) / 2 ))
  right=$(( W - len - left ))
  printf '%*s%s%*s' "$left" '' "$s" "$right" ''
}

bar="$(printf '─%.0s' $(seq 1 "$W"))"
t1="$(pad 'APPROVAL NEEDED  --  CLAUDE WANTS TO RUN SOMETHING')"
t2="$(pad 'review the request above, then approve or deny')"

top="${BORDER}┌${bar}┐${RESET}"
title="${BORDER}│${TITLEBG}${TITLEFG}${t1}${RESET}${BORDER}│${RESET}"
body="${BORDER}│${BODY}${t2}${RESET}${BORDER}│${RESET}"
bot="${BORDER}└${bar}┘${RESET}"

printf '\a\n%s\n%s\n%s\n%s\n\n' "$top" "$title" "$body" "$bot"
