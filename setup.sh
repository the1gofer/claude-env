#!/usr/bin/env bash
# claude-env/setup.sh
# Bootstrap Claude Code environment by symlinking skills and agents from this repo.
# Supports macOS and Linux.
#
# Usage:
#   bash setup.sh           # First-time setup or re-link
#   bash setup.sh --force   # Re-link + overwrite MEMORY.md files

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
FORCE="${1:-}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $1"; }
ok()      { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
err()     { echo -e "${RED}[ERROR]${NC} $1"; }

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  claude-env setup${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Detect platform
if [[ "$(uname)" == "Darwin" ]]; then
    PLATFORM="mac"
    GOFER_STACK="$HOME/Documents/GitHub/gofer-stack"
else
    PLATFORM="linux"
    GOFER_STACK="$HOME/gofer-stack"
fi

info "Platform:    $PLATFORM"
info "Repo:        $REPO_DIR"
info "Claude dir:  $CLAUDE_DIR"
info "gofer-stack: $GOFER_STACK"
echo ""

# Ensure ~/.claude exists
mkdir -p "$CLAUDE_DIR"

# Helper: create or re-point a directory symlink
make_symlink() {
    local src="$1"
    local dst="$2"
    local label="$3"

    if [[ -L "$dst" ]]; then
        current_target="$(readlink "$dst")"
        if [[ "$current_target" == "$src" ]]; then
            ok "$label already linked → $src"
        else
            warn "$label points to $current_target — re-pointing to $src"
            rm "$dst"
            ln -s "$src" "$dst"
            ok "$label re-linked → $src"
        fi
    elif [[ -d "$dst" ]]; then
        backup="${dst}.bak.$(date +%Y%m%d%H%M%S)"
        warn "$dst is a real directory. Backing up to $backup"
        mv "$dst" "$backup"
        ln -s "$src" "$dst"
        ok "$label linked → $src (old dir backed up)"
    elif [[ -e "$dst" ]]; then
        err "$dst exists but is not a directory or symlink. Remove it manually."
        exit 1
    else
        ln -s "$src" "$dst"
        ok "$label linked → $src"
    fi
}

# Symlink skills and agents
make_symlink "$REPO_DIR/skills"  "$CLAUDE_DIR/skills"  "skills/"
make_symlink "$REPO_DIR/agents"  "$CLAUDE_DIR/agents"  "agents/"
echo ""

# Build combined MEMORY.md content from the three memory files
build_memory() {
    cat "$REPO_DIR/memory/HOMELAB.md"
    echo ""
    echo "---"
    echo ""
    cat "$REPO_DIR/memory/SERVICES.md"
    echo ""
    echo "---"
    echo ""
    cat "$REPO_DIR/memory/COMMANDS.md"
}

# Write global ~/.claude/MEMORY.md
GLOBAL_MEMORY="$CLAUDE_DIR/MEMORY.md"
if [[ ! -f "$GLOBAL_MEMORY" ]] || [[ "$FORCE" == "--force" ]]; then
    build_memory > "$GLOBAL_MEMORY"
    ok "Global MEMORY.md written → $GLOBAL_MEMORY"
else
    info "Global MEMORY.md already exists (use --force to overwrite)"
fi

# Write project-specific MEMORY.md
# Claude Code stores project memory at ~/.claude/projects/<encoded-path>/memory/MEMORY.md
# The encoded path replaces '/' with '-'
if [[ "$PLATFORM" == "mac" ]]; then
    ENCODED_PATH="-Users-$(whoami)-Documents-GitHub"
    PROJECT_MEMORY_DIR="$CLAUDE_DIR/projects/$ENCODED_PATH/memory"
else
    ENCODED_PATH="-home-$(whoami)-gofer-stack"
    PROJECT_MEMORY_DIR="$CLAUDE_DIR/projects/$ENCODED_PATH/memory"
fi

mkdir -p "$PROJECT_MEMORY_DIR"
PROJECT_MEMORY="$PROJECT_MEMORY_DIR/MEMORY.md"

if [[ ! -f "$PROJECT_MEMORY" ]] || [[ "$FORCE" == "--force" ]]; then
    build_memory > "$PROJECT_MEMORY"
    ok "Project MEMORY.md written → $PROJECT_MEMORY"
else
    info "Project MEMORY.md already exists (use --force to overwrite)"
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Setup complete!${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Verify symlinks:"
echo "    ls -la ~/.claude/skills ~/.claude/agents"
echo ""
echo "  Available skills in Claude Code:"
echo "    /ssh [host]        — SSH into any homelab host"
echo "    /infra [filter]    — Infrastructure health check"
echo "    /scripts [filter]  — List/run gofer-stack scripts"
echo "    /sync [host]       — Sync configs to servers"
echo ""
echo "  Available agents:"
echo "    homelab-ops        — Full homelab context agent"
echo ""
echo "  To update from GitHub on any machine:"
echo "    cd $REPO_DIR && git pull && bash setup.sh"
echo ""
