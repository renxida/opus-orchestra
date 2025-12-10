#!/bin/bash
# Initialize .claude-agents/ directory in a repository
# Usage: init-agents.sh <repo-path> <backlog-path>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REPO_PATH="${1:-.}"
BACKLOG_PATH="${2:-}"

# Convert to absolute path
REPO_PATH="$(cd "$REPO_PATH" && pwd)"

AGENTS_DIR="$REPO_PATH/.claude-agents"
CLAUDE_DIR="$REPO_PATH/.claude"

echo "Initializing Claude agents in: $REPO_PATH"

# Create directories
mkdir -p "$AGENTS_DIR/completed"
mkdir -p "$CLAUDE_DIR/commands"
mkdir -p "$CLAUDE_DIR/skills"

# Copy task claimer
cp "$SCRIPT_DIR/task-claimer.sh" "$AGENTS_DIR/"
chmod +x "$AGENTS_DIR/task-claimer.sh"

# Copy CLAUDE.md
cp "$SCRIPT_DIR/agent-CLAUDE.md" "$AGENTS_DIR/CLAUDE.md"

# Copy slash commands
cp "$SCRIPT_DIR/commands/"*.md "$CLAUDE_DIR/commands/"

# Copy skills
if [[ -d "$SCRIPT_DIR/skills" ]]; then
    cp -r "$SCRIPT_DIR/skills/"* "$CLAUDE_DIR/skills/"
    echo "Installed skills to $CLAUDE_DIR/skills/"
fi

# Create or update backlog symlink
if [[ -n "$BACKLOG_PATH" ]]; then
    # Convert to absolute if relative
    if [[ ! "$BACKLOG_PATH" = /* ]]; then
        BACKLOG_PATH="$(cd "$(dirname "$BACKLOG_PATH")" && pwd)/$(basename "$BACKLOG_PATH")"
    fi

    # Remove existing symlink/directory
    rm -rf "$AGENTS_DIR/backlog"

    # Create symlink (use relative path for portability)
    ln -s "$BACKLOG_PATH" "$AGENTS_DIR/backlog"
    echo "Linked backlog to: $BACKLOG_PATH"
else
    # Create empty backlog directory if no path specified
    mkdir -p "$AGENTS_DIR/backlog"
    echo "Created empty backlog directory"
fi

# Initialize empty claims file
touch "$AGENTS_DIR/claims.jsonl"

# Add to .gitignore
GITIGNORE="$REPO_PATH/.gitignore"
if [[ -f "$GITIGNORE" ]]; then
    if ! grep -q "^\.claude-agents/completed/$" "$GITIGNORE" 2>/dev/null; then
        echo "" >> "$GITIGNORE"
        echo "# Claude agents coordination" >> "$GITIGNORE"
        echo ".claude-agents/completed/" >> "$GITIGNORE"
        echo ".claude-agents/claims.jsonl" >> "$GITIGNORE"
        echo ".claude-agents/.claims.lock" >> "$GITIGNORE"
    fi
else
    echo "# Claude agents coordination" > "$GITIGNORE"
    echo ".claude-agents/completed/" >> "$GITIGNORE"
    echo ".claude-agents/claims.jsonl" >> "$GITIGNORE"
    echo ".claude-agents/.claims.lock" >> "$GITIGNORE"
fi

# Create settings.json to restrict permissions
mkdir -p "$AGENTS_DIR/.claude"
cat > "$AGENTS_DIR/.claude/settings.json" << 'EOF'
{
  "permissions": {
    "deny": [
      "Edit:.claude-agents/task-claimer.sh",
      "Edit:.claude-agents/claims.jsonl",
      "Edit:.claude-agents/CLAUDE.md",
      "Write:.claude-agents/task-claimer.sh",
      "Write:.claude-agents/claims.jsonl",
      "Write:.claude-agents/CLAUDE.md"
    ]
  }
}
EOF

echo ""
echo "Claude agents initialized!"
echo ""
echo "Directory structure:"
echo "  $AGENTS_DIR/"
echo "  ├── CLAUDE.md           # Agent instructions"
echo "  ├── task-claimer.sh     # Coordination script"
echo "  ├── claims.jsonl        # Claim log"
echo "  ├── backlog/            # Task files"
echo "  └── completed/          # Finished tasks"
echo ""
echo "Slash commands installed in $CLAUDE_DIR/commands/:"
echo "  /claim <task>  - Claim a task"
echo "  /complete      - Mark current task complete"
echo "  /tasks         - List available tasks"
echo "  /my-task       - Show your claimed task"
echo ""
echo "Skills installed in $CLAUDE_DIR/skills/:"
echo "  task-coordination - Atomic task claiming and coordination"
echo ""
echo "Next steps:"
echo "  1. Add task files to the backlog"
echo "  2. Create agent worktrees with the VS Code extension"
echo "  3. Agents will auto-claim tasks and coordinate via the script"
