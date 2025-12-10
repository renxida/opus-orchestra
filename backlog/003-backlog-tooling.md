# Backlog Tooling

## Summary

Enhanced backlog management with multiple backlog support, filtering, and better visibility for agents and conductors.

## Motivation

Current backlog is a simple list. Real projects need:
- Multiple backlogs (by component, team, priority)
- Filtering and search
- Agents need visibility into what's available
- Conductors need overview to assign non-overlapping work

## Design

### Multiple Backlogs

Support multiple backlog sources that can be enabled/disabled:

```
Backlogs:
├── Local (./backlog/)           [enabled]
├── GitHub Issues                [enabled]
├── Project Alpha (/shared/...)  [disabled]
└── + Add Backlog Source
```

**Backlog Sources**:
1. **Local directory**: Markdown files in a folder
2. **GitHub Issues**: Synced from repo (see 002)
3. **Remote directory**: Shared network/cloud path
4. **Symlinked**: External folder symlinked into project

### Settings UI

**Backlog Configuration Panel**:
```
┌─────────────────────────────────────────────────────────┐
│ Backlog Sources                                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ [✓] Local Backlog                          [Edit]   │ │
│ │     Path: ./backlog                                 │ │
│ │     Tasks: 12 (3 high, 5 medium, 4 low)            │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ [✓] GitHub Issues                          [Edit]   │ │
│ │     Repo: owner/repo                                │ │
│ │     Tasks: 8 (synced 2 min ago)                    │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ [ ] Shared Team Backlog                    [Edit]   │ │
│ │     Path: /mnt/shared/team-backlog                  │ │
│ │     (disabled)                                      │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ [+ Add Backlog Source]                                  │
│                                                         │
│ ─────────────────────────────────────────────────────── │
│                                                         │
│ Display Options:                                        │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Group by:    [Source ▼] [Category] [Priority]       │ │
│ │ Sort by:     [Priority ▼] [Created] [Updated]       │ │
│ │ Show:        [✓] Available  [✓] In Progress  [ ] Done│
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Add Backlog Source Dialog**:
```
┌─────────────────────────────────────────────────────────┐
│ Add Backlog Source                                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ Type: ○ Local Directory                                 │
│       ○ GitHub Issues (configure in GitHub settings)    │
│       ○ Remote/Shared Path                              │
│                                                         │
│ Name: [Team Backlog_______________]                     │
│                                                         │
│ Path: [/mnt/shared/backlog________] [Browse...]         │
│                                                         │
│ Options:                                                │
│ [✓] Watch for changes                                   │
│ [✓] Include in agent visibility                         │
│ [ ] Read-only (don't modify tasks)                      │
│                                                         │
│                              [Cancel]  [Add Source]     │
└─────────────────────────────────────────────────────────┘
```

### Sidebar Backlog View

Enhanced tree view with filtering:

```
BACKLOG                              [Filter] [+] [⚙]
─────────────────────────────────────────────────────
▼ High Priority (3)
  ● Fix auth bypass vulnerability     [Local]
  ● Database migration failing        [GitHub #42]
  ● API rate limiting broken          [Local]

▼ Frontend (5)
  ○ Implement dark mode toggle        [GitHub #38]
  ○ Fix mobile navigation             [Local]
  ○ Add loading spinners              [Local]
  ...

▼ Backend (4)
  ...

───────────────────────────────────────
Filter: [________________________] [×]
[All] [Available] [My Tasks]
```

**Filter Bar**:
- Text search across title/description
- Quick filters: All, Available (unassigned), My Tasks
- Category/label filter chips
- Priority filter

### Agent Visibility

Agents can query the backlog via a coordination file or API:

**`.claude-coordination/available-tasks.md`** (auto-generated):
```markdown
# Available Tasks

## High Priority
- [ ] Fix auth bypass vulnerability (category: security)
- [ ] Database migration failing (category: backend)

## By Category

### Frontend
- [ ] Implement dark mode toggle
- [ ] Fix mobile navigation

### Backend
- [ ] API rate limiting broken
- [ ] Add caching layer
```

This file is:
- Auto-regenerated when backlog changes
- Filtered to show only unassigned tasks
- Grouped by conductor's preference
- Read by agents to understand available work

### Conductor View

Special view for conductor agent (see 004-conductor-agent.md):

```
┌─────────────────────────────────────────────────────────┐
│ Task Assignment Overview                                │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ Unassigned Tasks: 15                                    │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Task                    Category    Overlaps With   │ │
│ │ Fix auth bypass         security    -               │ │
│ │ Add dark mode           frontend    mobile-nav      │ │
│ │ API rate limiting       backend     caching         │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ Active Agents: 3                                        │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Agent      Current Task         Categories          │ │
│ │ Agent-1    Mobile navigation    frontend, css       │ │
│ │ Agent-2    Database migration   backend, db         │ │
│ │ Agent-3    (idle)               -                   │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ Suggested Assignment:                                   │
│ → Agent-3: "API rate limiting" (backend, no overlap)   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Implementation Steps

1. **Backlog Source Abstraction**:
   - `BacklogSource` interface
   - `LocalBacklogSource`: Read markdown files from directory
   - `GitHubBacklogSource`: Sync with GitHub Issues
   - `RemoteBacklogSource`: Watch remote directory
2. **Backlog Manager**:
   - Aggregate tasks from multiple sources
   - Handle enable/disable
   - Watch for changes
   - Merge and deduplicate
3. **Settings UI**:
   - Backlog sources configuration panel
   - Add/edit/remove source dialogs
   - Display options
4. **Sidebar Enhancement**:
   - Filter bar component
   - Grouping logic
   - Source indicators
5. **Coordination File Generator**:
   - Watch backlog changes
   - Generate `available-tasks.md`
   - Filter and format for agent consumption
6. **Conductor View**:
   - Task/agent matrix
   - Overlap detection display
   - Assignment suggestions

## Open Questions

1. **Conflict handling**: Same task in multiple sources?
2. **Permissions**: Some sources read-only, others read-write?
3. **Offline**: Cache remote backlogs for offline use?

## Dependencies

- Task format specification (see 005-task-format.md)
- File system watcher for local sources
- GitHub integration for GitHub source (see 002)

## Risks

- Too many sources → UI clutter, performance
- Stale remote data → clear sync status indicators
- Large backlogs → pagination/virtual scrolling needed
