#!/bin/bash
# Bootstrap claude-env skills on a new machine.
# Run once per machine. Works on macOS and Linux (Proxmox/Debian).
#
# Usage: bash skills-bootstrap.sh

set -e

REPO_URL="git@github.com:the1gofer/claude-env.git"
REPO_DIR="$HOME/Documents/GitHub/claude-env"
SKILLS_DIR="$HOME/.claude/skills"

echo "==> Cloning claude-env repo..."
mkdir -p "$(dirname "$REPO_DIR")"
if [ -d "$REPO_DIR/.git" ]; then
    echo "    Repo already exists, pulling latest..."
    git -C "$REPO_DIR" pull
else
    git clone "$REPO_URL" "$REPO_DIR"
fi

echo "==> Symlinking ~/.claude/skills..."
mkdir -p "$HOME/.claude"
if [ -L "$SKILLS_DIR" ]; then
    echo "    Symlink already exists, skipping."
elif [ -d "$SKILLS_DIR" ]; then
    echo "    WARNING: $SKILLS_DIR is a real directory (not a symlink)."
    echo "    Move or remove it manually, then re-run this script."
    exit 1
else
    ln -s "$REPO_DIR/skills" "$SKILLS_DIR"
    echo "    Linked $SKILLS_DIR -> $REPO_DIR/skills"
fi

echo "==> Setting up auto-pull..."

OS="$(uname)"

if [ "$OS" = "Darwin" ]; then
    # macOS — LaunchAgent polling every 15 minutes
    PLIST="$HOME/Library/LaunchAgents/com.claude.skills-pull.plist"
    cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.claude.skills-pull</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>git -C $REPO_DIR pull --ff-only >> $HOME/Library/Logs/claude-skills-pull.log 2>&1</string>
    </array>
    <key>StartInterval</key>
    <integer>900</integer>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF
    launchctl unload "$PLIST" 2>/dev/null || true
    launchctl load "$PLIST"
    echo "    LaunchAgent installed (pulls every 15 min)"

else
    # Linux — cron job every 15 minutes
    CRON_CMD="*/15 * * * * git -C $REPO_DIR pull --ff-only >> $HOME/claude-skills-pull.log 2>&1"
    if crontab -l 2>/dev/null | grep -qF "claude-env"; then
        echo "    Cron job already exists, skipping."
    else
        (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
        echo "    Cron job installed (pulls every 15 min)"
    fi
fi

echo ""
echo "Done! Skills will auto-pull every 15 minutes on this machine."
echo "Repo: $REPO_URL"
