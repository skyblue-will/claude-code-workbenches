#!/usr/bin/env bash
# Bootstrap a fresh Ubuntu/Debian VPS into a workbench host.
# Run as a normal user with sudo rights:  bash bootstrap-vps.sh
#
# What it does: installs tmux + Claude Code, clones this repo, and installs
# the reboot cron from WIRING.md so the front door comes back by itself.
# What it deliberately does NOT do: log you in or trust directories for you.
# Credentials and trust decisions should never be scripted.
set -euo pipefail

echo "== workbench host bootstrap =="

# 1. tmux, git, curl
sudo apt-get update -y
sudo apt-get install -y tmux git curl

# 2. Claude Code (native installer; auto-updates in the background)
if ! command -v claude >/dev/null 2>&1; then
  curl -fsSL https://claude.ai/install.sh | bash
  export PATH="$HOME/.local/bin:$PATH"
fi
echo "Claude Code: $(claude --version)"

# 3. A home for work
mkdir -p "$HOME/repos"

# 4. This repo, for the spawn script
if [ ! -d "$HOME/claude-code-workbenches" ]; then
  git clone https://github.com/skyblue-will/claude-code-workbenches "$HOME/claude-code-workbenches"
fi
chmod +x "$HOME/claude-code-workbenches/spawn-remote.sh"

# 5. The front door comes back after a reboot (see WIRING.md)
CRON_LINE="@reboot sleep 30 && PATH=/usr/local/bin:/usr/bin:/bin:\$HOME/.local/bin \$HOME/claude-code-workbenches/spawn-remote.sh front-door \$HOME/repos 'Read CLAUDE.md. You are the front door: you open other workbenches on request.'"
( crontab -l 2>/dev/null | grep -v "spawn-remote.sh front-door" || true; echo "$CRON_LINE" ) | crontab -
echo "Reboot cron installed."

echo
echo "Done. Two one-time manual steps remain:"
echo "  1. Log in: run 'claude' and follow the prompt (needs a Pro or Max plan)."
echo "  2. Run 'claude' once in each directory you'll work in and accept the trust dialog."
echo
echo "Then spawn your first bench:"
echo "  ~/claude-code-workbenches/spawn-remote.sh myagent ~/repos 'Introduce yourself.'"
