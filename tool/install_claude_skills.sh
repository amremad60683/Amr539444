#!/usr/bin/env bash
# Installs the design skills used on this project into .claude/skills
# (git-ignored, so third-party code is not committed). Pinned to the commits
# that were reviewed when the app was redesigned.
#
#   bash tool/install_claude_skills.sh
#
# Skills:
#   impeccable               https://github.com/pbakaus/impeccable
#   taste-skill              https://github.com/Leonxlnx/taste-skill
#   web-interface-guidelines https://github.com/vercel-labs/web-interface-guidelines
#
# MCP servers (Playwright, Figma) are configured in .mcp.json.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/.claude/skills"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$DEST"

fetch() { # repo commit dir
  git init -q "$TMP/$3"
  git -C "$TMP/$3" fetch -q --depth 1 "https://github.com/$1.git" "$2"
  git -C "$TMP/$3" checkout -q FETCH_HEAD
}

fetch pbakaus/impeccable 695cea5c6d1cbd420fc331375c7ef126a774e5f7 impeccable
fetch Leonxlnx/taste-skill 12af471f627f866411b4bd785b19646d3672784c taste-skill
fetch vercel-labs/web-interface-guidelines 434b7f91364665f2f733b310ec54809bf8f37937 wig

rm -rf "$DEST/impeccable" "$DEST/taste-skill" "$DEST/web-interface-guidelines"
cp -R "$TMP/impeccable/.claude/skills/impeccable" "$DEST/impeccable"
cp -R "$TMP/taste-skill/skills/taste-skill" "$DEST/taste-skill"
mkdir -p "$DEST/web-interface-guidelines"
{
  printf -- '---\nname: web-interface-guidelines\n'
  printf -- 'description: Vercel interface guidelines (MUST/SHOULD/NEVER rules for interactions, animation, layout, content, accessibility, dark mode). Use when reviewing or building UI.\n---\n\n'
  cat "$TMP/wig/AGENTS.md"
} > "$DEST/web-interface-guidelines/SKILL.md"

echo "Installed into $DEST:"
ls "$DEST"
