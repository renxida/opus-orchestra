# Multi-Repository Support

## Summary

Manage agents across multiple repositories, each with its own conductor and worker agents, with a unified dashboard view.

## Motivation

Real projects often span multiple repositories:
- Monorepos with separate services
- Frontend/backend split
- Shared libraries
- Microservices

Current single-repo focus means:
- Switching repos loses agent state
- Can't see all agents at once
- Manual coordination between repos
- Repeated configuration

Multi-repo support enables:
- Unified view of all agents
- Per-repo conductors (no cross-repo coordination)
- Shared configuration profiles
- Quick switching between repos

## Design

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Opus Orchestra (VS Code)                                │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────┐    ┌─────────────────┐            │
│  │   Repository A  │    │   Repository B  │            │
│  ├─────────────────┤    ├─────────────────┤            │
│  │ Conductor-A     │    │ Conductor-B     │            │
│  │ ├─ Agent-A1     │    │ ├─ Agent-B1     │            │
│  │ ├─ Agent-A2     │    │ └─ Agent-B2     │            │
│  │ └─ Agent-A3     │    │                 │            │
│  └─────────────────┘    └─────────────────┘            │
│                                                         │
│  Unified Dashboard:                                     │
│  [Repo A ▼] Agent-A1, Agent-A2, Agent-A3               │
│  [Repo B ▼] Agent-B1, Agent-B2                         │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Key Principle: No Cross-Repo Coordination

Each repository is an isolated domain:
- Its own conductor
- Its own backlog
- Its own worktrees
- Its own git history

The extension provides unified visibility, not unified coordination.

### Repository Management

**Settings UI**:
```
┌─────────────────────────────────────────────────────────┐
│ Repositories                                            │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ Active Repositories:                                    │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ ★ frontend-app     ~/projects/frontend              │ │
│ │   3 agents, 1 conductor                    [Remove] │ │
│ │                                                     │ │
│ │   backend-api      ~/projects/backend               │ │
│ │   2 agents, 1 conductor                    [Remove] │ │
│ │                                                     │ │
│ │   shared-lib       ~/projects/shared                │ │
│ │   0 agents                                 [Remove] │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ [+ Add Repository]  [Detect from Workspace]            │
│                                                         │
│ ★ = Primary (current workspace)                        │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Add Repository Dialog**:
```
┌─────────────────────────────────────────────────────────┐
│ Add Repository                                          │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ Path: [~/projects/backend_________] [Browse...]         │
│                                                         │
│ Name: [backend-api________________] (display name)      │
│                                                         │
│ Options:                                                │
│ [✓] Watch for changes                                   │
│ [✓] Show in unified dashboard                           │
│ [ ] Auto-create conductor on first agent                │
│                                                         │
│ Default profile: [conservative ▼]                       │
│                                                         │
│                              [Cancel]  [Add]            │
└─────────────────────────────────────────────────────────┘
```

### Unified Dashboard

**Multi-repo view**:
```
┌─────────────────────────────────────────────────────────┐
│ Opus Orchestra Dashboard                   [Settings]   │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ View: [All Repos ▼]  [frontend-app] [backend-api]      │
│                                                         │
│ ═══════════════════════════════════════════════════════ │
│ frontend-app (3 agents)                     [+ Agent]   │
│ ───────────────────────────────────────────────────────│
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐        │
│ │ Conductor   │ │ Agent-1     │ │ Agent-2     │        │
│ │ Coordinating│ │ Working     │ │ Waiting     │        │
│ │             │ │ +42 -12     │ │ approval    │        │
│ └─────────────┘ └─────────────┘ └─────────────┘        │
│                                                         │
│ ═══════════════════════════════════════════════════════ │
│ backend-api (2 agents)                      [+ Agent]   │
│ ───────────────────────────────────────────────────────│
│ ┌─────────────┐ ┌─────────────┐                        │
│ │ Conductor   │ │ Agent-1     │                        │
│ │ Coordinating│ │ Idle        │                        │
│ └─────────────┘ └─────────────┘                        │
│                                                         │
│ ═══════════════════════════════════════════════════════ │
│ shared-lib (no agents)                      [+ Agent]   │
│ ───────────────────────────────────────────────────────│
│ No agents. Click [+ Agent] to create one.              │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Sidebar Integration

**Tree View with Repos**:
```
AGENTS                                    [+] [⚙]
─────────────────────────────────────────────────
▼ frontend-app (3)
  ★ Conductor
  ● Agent-1 (working)
  ○ Agent-2 (waiting approval)

▼ backend-api (2)
  ★ Conductor
  ○ Agent-1 (idle)

▶ shared-lib (0)
─────────────────────────────────────────────────
```

### Workspace Detection

Automatically detect repositories:
- Current workspace folder
- Git submodules
- Multi-root workspace folders
- Parent monorepo if in subdirectory

**Auto-detect prompt**:
```
┌─────────────────────────────────────────────────────────┐
│ Detected Repositories                                   │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ Found 3 git repositories in workspace:                  │
│                                                         │
│ [✓] ~/projects/monorepo/frontend                       │
│ [✓] ~/projects/monorepo/backend                        │
│ [ ] ~/projects/monorepo/docs (no package.json)         │
│                                                         │
│                    [Add Selected]  [Skip]               │
└─────────────────────────────────────────────────────────┘
```

### Per-Repo Configuration

Each repo can have its own `.opus-orchestra/config.json`:
- Overrides global settings
- Defines repo-specific profiles
- Sets default conductor behavior
- Specifies backlog location

Configuration is fully isolated between repos.

### Quick Switching

**Command Palette**:
- "Opus Orchestra: Switch to Repository" → quick pick list
- "Opus Orchestra: Focus Agent in [repo]" → agent picker filtered by repo

**Keyboard Shortcuts**:
- `Ctrl+Shift+1` through `Ctrl+Shift+9` for quick repo switch (configurable)

**Status Bar**:
```
[frontend-app: 3 agents ▼]
```
Click to switch repos or see agent summary.

### Terminal Management

Terminals are labeled with repo context:
```
Agent-1 (frontend-app)
Agent-2 (frontend-app)
Agent-1 (backend-api)
Conductor (backend-api)
```

### Implementation Steps

1. **Repository Manager**:
   - Track multiple repos
   - Store in VS Code workspace state
   - Handle add/remove/detect
2. **Per-Repo Agent Manager**:
   - Separate AgentManager instance per repo
   - Or single manager with repo-scoped operations
3. **Dashboard Updates**:
   - Repo grouping view
   - Repo filter/selector
   - Collapsed/expanded sections
4. **Sidebar Updates**:
   - Repo-level tree nodes
   - Repo badges with agent count
5. **Settings UI**:
   - Repository management panel
   - Auto-detection options
6. **Quick Navigation**:
   - Command palette commands
   - Keyboard shortcuts
   - Status bar picker
7. **Terminal Labels**:
   - Include repo name in terminal title
   - Color coding per repo (optional)

### Persistence

**Workspace State**:
```json
{
  "repositories": [
    {
      "path": "/home/user/projects/frontend",
      "name": "frontend-app",
      "enabled": true,
      "agents": ["agent-1", "agent-2", "conductor"]
    },
    {
      "path": "/home/user/projects/backend",
      "name": "backend-api",
      "enabled": true,
      "agents": ["agent-1", "conductor"]
    }
  ]
}
```

Each repo's agent data is stored separately to avoid conflicts.

## Open Questions

1. **Monorepo handling**: Treat as one repo or multiple?
2. **Shared worktree directory**: One .worktrees per repo, or shared parent?
3. **Cross-repo tasks**: Allow referencing tasks from other repos? (probably not)
4. **Resource limits**: Max agents across all repos?

## Dependencies

- Conductor agent (see 004-conductor-agent.md) for per-repo conductors
- Agent configuration (see 006-agent-configuration.md) for per-repo profiles

## Risks

- Complexity creep → keep repos isolated, no cross-repo features
- Resource exhaustion → warn when too many agents total
- Confusion → clear visual separation between repos
