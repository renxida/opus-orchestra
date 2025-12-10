# Conductor Agent

## Summary

A designated coordinator agent that assigns non-overlapping tasks to worker agents, tracks progress, and manages the overall workflow. One conductor per repository.

## Motivation

Without coordination, agents may:
- Pick overlapping tasks that cause merge conflicts
- Work on related tasks separately instead of together
- Leave important tasks unassigned
- Duplicate effort

A conductor agent solves this by:
- Analyzing task dependencies and categories
- Assigning related tasks to the same agent
- Ensuring non-overlapping work across agents
- Monitoring progress and reassigning if needed

## Design

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Repository                                              │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────┐                                    │
│  │   Conductor     │ ← Reads backlog, assigns tasks     │
│  │   (Agent-0)     │ ← Monitors agent progress          │
│  └────────┬────────┘ ← Resolves conflicts               │
│           │                                             │
│     ┌─────┴─────┬─────────┐                            │
│     ▼           ▼         ▼                            │
│ ┌───────┐  ┌───────┐  ┌───────┐                        │
│ │Agent-1│  │Agent-2│  │Agent-3│  ← Worker agents       │
│ │Task A │  │Task B │  │Task C │                        │
│ └───────┘  └───────┘  └───────┘                        │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Conductor Responsibilities

1. **Task Analysis**:
   - Read available tasks from backlog
   - Identify task categories and file overlap
   - Detect dependencies between tasks
   - Group related tasks

2. **Assignment**:
   - Match tasks to available agents
   - Prefer assigning related tasks to same agent
   - Avoid assigning tasks that touch same files
   - Balance workload across agents

3. **Monitoring**:
   - Track which agents are working/idle
   - Detect stuck or blocked agents
   - Identify when tasks complete

4. **Coordination**:
   - Update coordination files
   - Signal agents when new work available
   - Handle task completion and reassignment

### Conductor Does NOT:

- Coordinate between agents directly (no agent-to-agent messaging)
- Make code changes (only reads, assigns, monitors)
- Resolve merge conflicts (human responsibility)
- Approve permissions (human responsibility)

### Designation

**UI for designating conductor**:
```
┌─────────────────────────────────────────────────────────┐
│ Agent-1                                    [★ Conductor]│
├─────────────────────────────────────────────────────────┤
│ Status: Coordinating                                    │
│ Workers: 3 active, 1 idle                               │
│ Tasks: 12 assigned, 8 available                         │
│                                                         │
│ [View Assignments]  [Pause Coordination]                │
└─────────────────────────────────────────────────────────┘
```

**Settings**:
```
┌─────────────────────────────────────────────────────────┐
│ Conductor Settings                                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ Conductor Agent: [Agent-1 ▼] [None - Manual Assignment] │
│                                                         │
│ Assignment Strategy:                                    │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ ○ Minimize file overlap (recommended)               │ │
│ │ ○ Group by category                                 │ │
│ │ ○ Priority-first                                    │ │
│ │ ○ Round-robin                                       │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ Overlap Detection:                                      │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ [✓] Analyze file paths in task descriptions         │ │
│ │ [✓] Use category tags                               │ │
│ │ [✓] Consider declared dependencies                  │ │
│ │ [ ] ML-based similarity (experimental)              │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ Auto-Assignment:                                        │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ [✓] Auto-assign when agent becomes idle             │ │
│ │ [ ] Require conductor approval for assignments      │ │
│ │ [✓] Notify when no suitable tasks available         │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Coordination Protocol

**Conductor writes to `.claude-coordination/assignments.md`**:
```markdown
# Current Assignments

| Agent | Task | Category | Status | Assigned |
|-------|------|----------|--------|----------|
| Agent-1 | Fix auth bypass | security | in-progress | 10:30 |
| Agent-2 | Database migration | backend | in-progress | 10:25 |
| Agent-3 | Dark mode toggle | frontend | in-progress | 10:35 |
| Agent-4 | - | - | idle | - |

# Assignment Notes

- Agent-1 and Agent-2 both working on backend, but different subsystems
- Agent-3 assigned frontend work to avoid overlap with Agent-1's security fixes
- Agent-4 waiting for "API caching" task to be unblocked (depends on Agent-2)

# Next Up

When Agent-2 completes:
→ Assign "API caching" to Agent-4 (dependency resolved)

When Agent-3 completes:
→ Assign "Mobile navigation" (same frontend category)
```

**Agents read assignments to know their task**:
```markdown
# Agent-2 Assignment

Task: Database migration
Category: backend
Dependencies: none
Files likely touched: src/db/*, migrations/*

## Instructions
[Task description from backlog]

## Coordination Notes
- Agent-4 is waiting on this task to complete
- Avoid modifying src/api/* (Agent-1 working there)
```

### Overlap Detection

**Methods**:
1. **File path analysis**: Parse task descriptions for file paths
2. **Category matching**: Tasks in same category may overlap
3. **Dependency graph**: Explicit dependencies in task format
4. **Historical**: Learn from past merge conflicts

**Overlap Matrix** (conductor view):
```
         Task A  Task B  Task C  Task D
Task A     -      LOW    HIGH    NONE
Task B    LOW      -     NONE    MED
Task C   HIGH    NONE     -      LOW
Task D   NONE     MED    LOW      -
```

### Implementation Steps

1. **Conductor Agent Type**:
   - New agent mode: "conductor" vs "worker"
   - Different CLAUDE.md instructions for conductor
   - Conductor-specific terminal output parsing
2. **Assignment Engine**:
   - `analyzeTaskOverlap()`: Compute overlap matrix
   - `suggestAssignment()`: Find best task for idle agent
   - `assignTask()`: Update coordination files
3. **Coordination Files**:
   - Generate `assignments.md`
   - Per-agent assignment files
   - Watch for agent completion signals
4. **UI Components**:
   - Conductor designation in agent card
   - Assignment overview panel
   - Overlap visualization
5. **Settings UI**:
   - Conductor selection
   - Strategy configuration
   - Overlap detection options
6. **Conductor CLAUDE.md**:
   - Instructions for conductor behavior
   - How to read backlog
   - How to write assignments
   - Monitoring guidance

### Conductor CLAUDE.md Template

```markdown
# Conductor Agent Instructions

You are the coordinator for this repository. Your job is to:

1. READ the backlog at .claude-coordination/available-tasks.md
2. MONITOR agent status in .claude-coordination/status/
3. ASSIGN tasks by updating .claude-coordination/assignments.md
4. TRACK progress and reassign when agents complete

## Rules

- Never assign overlapping tasks (same files/category) to different agents
- Prefer assigning related tasks to the same agent
- Keep one task per agent at a time
- Update assignments.md whenever status changes

## Do NOT

- Write any code
- Make changes outside .claude-coordination/
- Communicate directly with other agents
- Approve any operations (human does this)

## Assignment Format

When assigning, create .claude-coordination/agent-N/assignment.md:
[template]
```

## Open Questions

1. **Conductor overhead**: Should conductor be full agent or lighter process?
2. **Multi-repo**: Separate conductor per repo, or one conductor across repos?
3. **Failure handling**: What if conductor agent crashes?
4. **Learning**: Should conductor learn from past assignment success/failure?

## Dependencies

- Task format specification (see 005-task-format.md)
- Backlog tooling (see 003-backlog-tooling.md)
- Agent status tracking (existing)

## Risks

- Conductor becomes bottleneck → keep coordination lightweight
- Poor assignments → allow manual override
- Conductor conflicts with workers → clear file ownership rules
