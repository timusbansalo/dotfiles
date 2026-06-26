#!/usr/bin/env bash
# input-banner.sh — CYAN "your turn / read this" banner for Claude Code.
#
# Fires on the Stop hook (Claude finished a turn and handed control back to you).
# Deliberately a different color from the PINK permission/approval banner so the
# distinction is instant:
#     PINK  = Claude wants you to APPROVE an action   (approval-banner.sh)
#     CYAN  = Claude is done, it's your turn to READ + reply   (this script)
#     plain = normal log lines (no banner — Claude Code emits these untagged)
#
# Interior text is ASCII-only on purpose (multibyte glyphs miscount column
# width in non-UTF-8 locales). Must be invoked with `> /dev/tty` in
# settings.json or Claude Code captures stdout and you never see it.

set -u

BORDER=$'\033[38;2;34;211;238m'       # bright cyan
TITLEBG=$'\033[48;2;8;145;178m'       # teal background
TITLEFG=$'\033[1;38;2;236;254;255m'   # near-white bold
BODY=$'\033[38;2;103;232;249m'        # soft cyan
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
t1="$(pad 'YOUR TURN  --  CLAUDE IS WAITING ON YOU')"
t2="$(pad 'read the output above, then reply')"

top="${BORDER}┌${bar}┐${RESET}"
title="${BORDER}│${TITLEBG}${TITLEFG}${t1}${RESET}${BORDER}│${RESET}"
body="${BORDER}│${BODY}${t2}${RESET}${BORDER}│${RESET}"
bot="${BORDER}└${bar}┘${RESET}"

printf '\a\n%s\n%s\n%s\n%s\n\n' "$top" "$title" "$body" "$bot"
