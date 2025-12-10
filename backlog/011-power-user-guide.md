# Power User / External Claude Guide

## Summary

A comprehensive reference document that external Claude instances (or power users) can read to understand all configuration points, customization options, and operational scripts in Opus Orchestra.

## Motivation

When using Claude outside the Opus Orchestra worktree (e.g., a separate Claude session helping configure the system), it needs to know:
- Where all configuration files live
- What format each file uses
- How to create/modify profiles, tasks, backlogs
- What scripts are available and how to run them
- How changes propagate to running agents

Currently this information is scattered across backlog plans and code. A single comprehensive guide enables:
- External Claude instances to help configure Opus Orchestra
- Power users to customize without reading source code
- Automation scripts to be written correctly
- Consistent configuration across projects

## Document Structure

The guide should be a single markdown file (`CONFIGURATION.md` or `POWER_USER_GUIDE.md`) at the repo root, organized as follows:

### 1. Overview & File Locations

```markdown
# Opus Orchestra Configuration Guide

## Quick Reference: Where Things Live

| What | Location | Format |
|------|----------|--------|
| Extension settings | VS Code settings.json | JSON |
| Project config | .opus-orchestra/config.json | JSON |
| Container config | .opus-orchestra/container.json | JSON |
| GitHub config | .opus-orchestra/github.json | JSON |
| Profiles | .opus-orchestra/profiles/*.json | JSON |
| Tasks | backlog/*.md | Markdown + YAML frontmatter |
| Agent coordination | .claude-coordination/ | Markdown |
| Agent worktrees | .worktrees/agent-N/ | Git worktree |
| Agent state | VS Code workspace state | Internal |
```

### 2. Project Configuration

```markdown
## Project Configuration

### .opus-orchestra/config.json

Master configuration file for the project. Created automatically or manually.

**Full Schema:**
```json
{
  // Default profile for new agents
  "defaultProfile": "conservative",

  // Custom profiles (merged with built-in)
  "profiles": {
    "my-profile": {
      "name": "my-profile",
      "description": "Description shown in UI",
      "extends": "conservative",  // Optional: inherit from another
      "permissions": {
        "fileRead": "allow|ask|deny",
        "fileWrite": "allow|ask|deny",
        "bash": "allow|ask|deny",
        "webSearch": "allow|ask|deny",
        "mcp": "allow|ask|deny"
      },
      "restrictions": {
        "allowedCommands": ["npm test", "npm run *"],
        "blockedCommands": ["rm -rf *", "sudo *"],
        "allowedPaths": ["src/*", "tests/*"],
        "blockedPaths": [".env*", "*.key"]
      },
      "claudeInstructions": [
        "Line 1 added to CLAUDE.md",
        "Line 2 added to CLAUDE.md"
      ]
    }
  },

  // Defaults applied to all agents
  "agentDefaults": {
    "behavior": {
      "branchNaming": "agent-{n}",
      "commitMessagePrefix": "[Agent-{n}]",
      "autoCommit": false
    }
  },

  // Backlog sources
  "backlogs": [
    {
      "name": "Local",
      "type": "local",
      "path": "./backlog",
      "enabled": true
    },
    {
      "name": "Shared",
      "type": "remote",
      "path": "/mnt/shared/team-backlog",
      "enabled": false,
      "readonly": true
    }
  ],

  // Conductor settings
  "conductor": {
    "enabled": false,
    "agentId": null,
    "strategy": "minimize-overlap"
  }
}
```

**Creating from scratch:**
```bash
mkdir -p .opus-orchestra
cat > .opus-orchestra/config.json << 'EOF'
{
  "defaultProfile": "conservative",
  "profiles": {},
  "agentDefaults": {}
}
EOF
```
```

### 3. Profiles

```markdown
## Profiles

### Built-in Profiles

These ship with Opus Orchestra and cannot be modified:

| Profile | Description |
|---------|-------------|
| conservative | Requires approval for all operations (default) |
| trusted-read | Can read freely, asks for writes |
| containerized | Full autonomy within container |
| conductor | Read-only, manages coordination files only |

### Creating Custom Profiles

**Option 1: In config.json**
Add to the `profiles` object in `.opus-orchestra/config.json`.

**Option 2: Separate file**
Create `.opus-orchestra/profiles/my-profile.json`:
```json
{
  "name": "my-profile",
  "description": "My custom profile",
  "extends": "conservative",
  "permissions": {
    "fileRead": "allow"
  },
  "restrictions": {
    "allowedCommands": ["npm *", "yarn *"]
  }
}
```

### Profile Inheritance

Profiles can extend others:
```json
{
  "extends": "trusted-read",
  "restrictions": {
    "blockedPaths": ["secrets/*"]  // Added to parent's blockedPaths
  }
}
```

Merge rules:
- Permissions: child overrides parent
- Arrays (allowedCommands, etc.): concatenated
- Objects: deep merged
- Explicit `null`: removes inherited value

### Applying Profiles to Agents

**Via UI:** Agent card → Settings → Add Profile

**Via coordination file:**
`.claude-coordination/agent-1/config.json`:
```json
{
  "profiles": ["conservative", "frontend-dev"]
}
```

**Via script:** See "Recalculating Agent Settings" below.
```

### 4. Tasks & Backlog

```markdown
## Tasks & Backlog

### Task Format

Tasks are markdown files with YAML frontmatter:

```markdown
---
id: task-20241210-143052
title: Implement user authentication
status: available
priority: high
category: [backend, security]
depends_on: [task-20241210-120000]
blocks: []
estimated_files: [src/auth/*]
created: 2024-12-10T14:30:52Z
---

# Implement user authentication

## Description

[Detailed description of the task]

## Acceptance Criteria

- [ ] Criterion 1
- [ ] Criterion 2

## Technical Notes

[Optional implementation hints]
```

### Creating Tasks

**Manual creation:**
```bash
cat > backlog/task-$(date +%Y%m%d-%H%M%S)-my-task.md << 'EOF'
---
id: task-$(date +%Y%m%d-%H%M%S)
title: My new task
status: available
priority: medium
category: []
depends_on: []
blocks: []
estimated_files: []
created: $(date -Iseconds)
---

# My new task

## Description

[Description here]

## Acceptance Criteria

- [ ] TODO
EOF
```

**Via VS Code command:** "Opus Orchestra: Create New Task"

### Task Status Values

| Status | Meaning |
|--------|---------|
| available | Ready to be assigned |
| assigned | Claimed by conductor, not started |
| in-progress | Agent actively working |
| blocked | Waiting on dependencies |
| completed | Done |
| cancelled | Won't be done |

### Adding Backlog Directories

**In config.json:**
```json
{
  "backlogs": [
    {
      "name": "Main",
      "type": "local",
      "path": "./backlog",
      "enabled": true
    },
    {
      "name": "Team Shared",
      "type": "local",
      "path": "/path/to/shared/backlog",
      "enabled": true,
      "readonly": true
    }
  ]
}
```

**Via symlink:**
```bash
ln -s /path/to/external/backlog .opus-orchestra/external-backlog
```
Then add to config.json backlogs array.

### Task Dependencies

```yaml
depends_on: [task-001, task-002]  # Can't start until these complete
blocks: [task-003]                 # These can't start until this completes
```

Dependencies are soft - conductor uses them for scheduling, but they're not enforced.
```

### 5. Container Configuration

```markdown
## Container Configuration

### .opus-orchestra/container.json

Configure containerized agent mode:

```json
{
  // Custom image (optional - defaults to opus-orchestra-sandbox)
  "image": "my-registry/my-image:latest",

  // Or build from Dockerfile
  "dockerfile": "./Dockerfile",
  "buildContext": ".",

  // Resource limits
  "memoryLimit": "4g",
  "cpuLimit": "2",

  // Network (none|bridge|host)
  "network": "none",

  // Allowed network hosts (if network != none)
  "allowedHosts": ["registry.npmjs.org", "pypi.org"],

  // Additional mounts (beyond worktree)
  "additionalMounts": [
    {
      "source": "./test-fixtures",
      "target": "/fixtures",
      "readonly": true
    }
  ],

  // Environment variables
  "environment": {
    "NODE_ENV": "development",
    "CI": "true"
  }
}
```

### Custom Dockerfile

Create `.opus-orchestra/Dockerfile`:
```dockerfile
FROM ghcr.io/kyleherndon/opus-orchestra-sandbox:latest

# Add project-specific dependencies
RUN apt-get update && apt-get install -y \
    postgresql-client \
    redis-tools

# Pre-install common packages
RUN npm install -g typescript eslint prettier

# Add any other setup
COPY .opus-orchestra/scripts/setup.sh /setup.sh
RUN chmod +x /setup.sh
```

### Security: What's NOT Mounted

Containers explicitly exclude:
- ~/.ssh (SSH keys)
- ~/.config/gh (GitHub CLI auth)
- ~/.aws (AWS credentials)
- ~/.gitconfig (Git credentials)
- ~/.netrc (Stored passwords)
```

### 6. GitHub Integration

```markdown
## GitHub Integration

### .opus-orchestra/github.json

```json
{
  // Labels that indicate tasks for agents
  "syncLabels": ["opus-orchestra", "agent-task"],

  // Labels to exclude
  "excludeLabels": ["wontfix", "duplicate", "question"],

  // Map labels to priorities
  "priorityLabels": {
    "critical": 1,
    "high": 2,
    "medium": 3,
    "low": 4
  },

  // Labels that become categories
  "categoryLabels": ["frontend", "backend", "docs", "tests", "security"],

  // Automation settings
  "autoClose": true,
  "autoCreatePR": true,
  "addInProgressLabel": true,

  // Poll interval in seconds
  "pollInterval": 300
}
```

### Authentication

GitHub API calls are made by the **extension only**, never by agents.

Configure in VS Code settings or via UI:
- Use `gh` CLI auth (recommended)
- Or provide Personal Access Token

Agents cannot access your GitHub credentials.
```

### 7. Coordination Files

```markdown
## Coordination Files

The `.claude-coordination/` directory is used for agent coordination.

### Directory Structure

```
.claude-coordination/
├── CLAUDE.md              # Instructions for all agents
├── available-tasks.md     # Auto-generated task list
├── assignments.md         # Conductor's assignment table
├── status/
│   ├── agent-1.json       # Agent 1 status
│   ├── agent-2.json       # Agent 2 status
│   └── ...
└── agent-1/
    ├── assignment.md      # Current assignment details
    └── config.json        # Agent-specific config overrides
```

### CLAUDE.md

Instructions prepended to every agent's context:
```markdown
# Project Instructions

You are working on [project name].

## Guidelines
- Follow existing code style
- Write tests for new functionality
- Update documentation

## Architecture
[Project-specific architecture notes]
```

### Agent Status Files

`.claude-coordination/status/agent-1.json`:
```json
{
  "agentId": "agent-1",
  "status": "working",
  "currentTask": "task-20241210-143052",
  "lastActivity": "2024-12-10T15:30:00Z",
  "lastOutput": "Updating authentication module..."
}
```

Agents update this periodically. Conductor reads it.

### Assignment Files

`.claude-coordination/agent-1/assignment.md`:
```markdown
# Current Assignment

Task: task-20241210-143052
Title: Implement user authentication

## Instructions
[Full task description]

## Coordination Notes
- Avoid src/api/* (Agent-2 working there)
- Agent-3 is waiting on this task
```
```

### 8. Scripts & Automation

```markdown
## Scripts & Automation

### Recalculating Agent Settings

When profiles or config.json changes, update existing agents:

```bash
#!/bin/bash
# recalculate-agent-settings.sh

REPO_ROOT=$(git rev-parse --show-toplevel)
WORKTREE_DIR="$REPO_ROOT/.worktrees"

for agent_dir in "$WORKTREE_DIR"/agent-*; do
    if [ -d "$agent_dir" ]; then
        agent_name=$(basename "$agent_dir")
        echo "Updating $agent_name..."

        # Copy updated coordination files
        cp -r "$REPO_ROOT/.claude-coordination" "$agent_dir/"

        # Copy updated project config
        cp -r "$REPO_ROOT/.opus-orchestra" "$agent_dir/"

        # Regenerate CLAUDE.md if needed
        # (Extension normally does this, but can be done manually)
    fi
done

echo "Done. Restart agents to pick up changes."
```

### Creating a New Task (Script)

```bash
#!/bin/bash
# create-task.sh <title> [priority] [category]

TITLE="$1"
PRIORITY="${2:-medium}"
CATEGORY="${3:-}"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')
FILENAME="backlog/task-${TIMESTAMP}-${SLUG:0:30}.md"

cat > "$FILENAME" << EOF
---
id: task-${TIMESTAMP}
title: ${TITLE}
status: available
priority: ${PRIORITY}
category: [${CATEGORY}]
depends_on: []
blocks: []
estimated_files: []
created: $(date -Iseconds)
---

# ${TITLE}

## Description

<!-- Describe the task -->

## Acceptance Criteria

- [ ] <!-- Criterion 1 -->

## Technical Notes

<!-- Optional -->
EOF

echo "Created: $FILENAME"
```

### Bulk Operations

**Mark all tasks in category as blocked:**
```bash
for f in backlog/*.md; do
    if grep -q "category:.*frontend" "$f"; then
        sed -i 's/status: available/status: blocked/' "$f"
    fi
done
```

**List all high-priority available tasks:**
```bash
grep -l "priority: high" backlog/*.md | while read f; do
    if grep -q "status: available" "$f"; then
        grep "^title:" "$f"
    fi
done
```

### Syncing Worktrees

```bash
#!/bin/bash
# sync-worktrees.sh - Pull latest main into all agent branches

REPO_ROOT=$(git rev-parse --show-toplevel)
MAIN_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')

for agent_dir in "$REPO_ROOT/.worktrees"/agent-*; do
    if [ -d "$agent_dir" ]; then
        echo "Syncing $(basename $agent_dir)..."
        cd "$agent_dir"
        git fetch origin
        git merge "origin/$MAIN_BRANCH" --no-edit || echo "Merge conflict in $(basename $agent_dir)"
        cd "$REPO_ROOT"
    fi
done
```

### Cleanup Completed Tasks

```bash
#!/bin/bash
# archive-completed.sh

mkdir -p backlog/archived

for f in backlog/*.md; do
    if grep -q "status: completed" "$f"; then
        mv "$f" backlog/archived/
        echo "Archived: $(basename $f)"
    fi
done
```
```

### 9. VS Code Settings Reference

```markdown
## VS Code Settings

All settings prefixed with `claudeAgents.`:

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| defaultAgentCount | number | 3 | Agents created by default |
| worktreeDirectory | string | .worktrees | Where worktrees are created |
| claudeCommand | string | claude | Command to start Claude |
| autoStartClaude | boolean | false | Auto-start Claude in new terminals |
| terminalType | enum | wsl | Terminal type (wsl/powershell/cmd/gitbash) |
| uiScale | number | 1.0 | Dashboard UI scale |
| statusPollingInterval | number | 1000 | Status check interval (ms) |
| diffPollingInterval | number | 60000 | Git diff refresh interval (ms) |
| containerMode | boolean | false | Enable containerized agents |
| containerImage | string | (default) | Docker image for containers |
| containerMemoryLimit | string | 4g | Container memory limit |
| containerCpuLimit | string | 2 | Container CPU limit |

### Example settings.json

```json
{
  "claudeAgents.defaultAgentCount": 4,
  "claudeAgents.terminalType": "wsl",
  "claudeAgents.autoStartClaude": true,
  "claudeAgents.containerMode": false,
  "claudeAgents.uiScale": 0.9
}
```
```

### 10. Troubleshooting & Common Tasks

```markdown
## Common Tasks

### "I want to add a new profile"

1. Edit `.opus-orchestra/config.json`
2. Add to `profiles` object
3. Run recalculate-agent-settings.sh (or restart extension)

### "I want to change what commands agents can run"

1. Edit profile in `.opus-orchestra/config.json`
2. Modify `restrictions.allowedCommands` or `restrictions.blockedCommands`
3. Recalculate settings

### "I want to add a shared backlog"

1. Edit `.opus-orchestra/config.json`
2. Add entry to `backlogs` array
3. Restart extension to pick up new source

### "I want to use a custom Docker image"

1. Create `.opus-orchestra/container.json`
2. Set `image` or provide `dockerfile`
3. Enable container mode in VS Code settings

### "I want to sync GitHub issues"

1. Configure `.opus-orchestra/github.json`
2. Set up authentication in VS Code settings
3. Enable GitHub integration in dashboard

### "Agents aren't picking up config changes"

1. Run recalculate-agent-settings.sh
2. Or restart the extension
3. Or restart individual agents

### "I want to see what config an agent is using"

Check `.worktrees/agent-N/.opus-orchestra/` - this is what the agent sees.
```

## Implementation Steps

1. **Create POWER_USER_GUIDE.md**:
   - Write comprehensive document following structure above
   - Include all JSON schemas with full field documentation
   - Add all script examples as copy-pasteable code blocks

2. **Create companion scripts**:
   - `scripts/recalculate-agent-settings.sh`
   - `scripts/create-task.sh`
   - `scripts/sync-worktrees.sh`
   - `scripts/archive-completed.sh`

3. **Add JSON schemas**:
   - `.opus-orchestra/schemas/config.schema.json`
   - `.opus-orchestra/schemas/profile.schema.json`
   - `.opus-orchestra/schemas/task.schema.json`
   - `.opus-orchestra/schemas/container.schema.json`
   - `.opus-orchestra/schemas/github.schema.json`

4. **Link from README**:
   - Add "For power users and external Claude: see POWER_USER_GUIDE.md"

## Document Principles

- **Self-contained**: Everything needed in one file
- **Copy-pasteable**: All scripts and JSON can be copied directly
- **Complete schemas**: Every field documented, even optional ones
- **Task-oriented**: Organized by "I want to do X"
- **No assumed knowledge**: Explains everything from scratch

## Open Questions

1. **Format**: Single .md file or multiple files with index?
2. **Location**: Repo root or docs/ folder?
3. **Versioning**: How to handle guide updates vs extension versions?

## Dependencies

- All other backlog items (documents their features)
- Stable config format

## Risks

- Doc drift from implementation → generate from schemas where possible
- Too long → good table of contents, search-friendly headings
- Missing edge cases → add as discovered
