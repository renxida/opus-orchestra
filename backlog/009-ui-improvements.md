# UI Improvements

## Summary

General dashboard and sidebar improvements for better usability, information clarity, and workflow efficiency.

## Current Pain Points

- Agent cards lack clear status information
- Approval workflow interrupts work
- Terminal output truncated/unclear
- Settings scattered across multiple places
- No keyboard navigation

## Design

### Enhanced Agent Cards

**Layout Philosophy**:
- Buttons grouped by semantic category
- Delete isolated (destructive action)
- Approve/Deny visually distinct and prominent
- Focus is navigation, separate from actions

**Improved Card Layout**:
```
┌───────────────────────────────────────────[×]─┐
│ Agent-1                                       │
│ Task: Fix auth bypass                         │
├───────────────────────────────────────────────┤
│ ● Working for 12m                             │
│   or                                          │
│ ○ Waiting for 3m                              │
│                                               │
│ Changes: +142 -38                             │
│                                               │
│ Latest: Updating jwt.ts validation...        │
├───────────────────────────────────────────────┤
│                                               │
│ ┌───────────────────────────────────────────┐ │
│ │ ⚠ PENDING APPROVAL                        │ │
│ │                                           │ │
│ │ Bash: npm install lodash                  │ │
│ │                                           │ │
│ │    [✓ Approve]    [✗ Deny]               │ │
│ └───────────────────────────────────────────┘ │
│                                               │
├───────────────────────────────────────────────┤
│ [Focus Terminal]  [Start Claude]  [⚙ More]   │
└───────────────────────────────────────────────┘
```

**Key Design Decisions**:
- **Delete (×)** in top-right corner, small and isolated
- **Approval section** is a distinct highlighted box, impossible to miss
- **Focus/Start/More** are navigation/utility, grouped at bottom
- **Status shows time since last event**: "Working for 12m" or "Waiting for 3m"
- No branch name (clutter), no duration timer (use event-based time)

### Approval Section Design

The approval section should be visually dominant when present:

```
┌─────────────────────────────────────────────────┐
│ ⚠ PENDING APPROVAL                              │
│ ─────────────────────────────────────────────── │
│                                                 │
│ Type: Bash Command                              │
│ ┌─────────────────────────────────────────────┐ │
│ │ npm install lodash @types/lodash            │ │
│ └─────────────────────────────────────────────┘ │
│                                                 │
│ Context: Adding utility library for deep clone │
│                                                 │
│         [✓ Approve]      [✗ Deny]              │
│                                                 │
│ [Approve & Allow Pattern] [View Full Request]  │
└─────────────────────────────────────────────────┘
```

**Features**:
- Yellow/orange warning color scheme
- Large, clear Approve/Deny buttons
- Secondary actions below (smaller)
- Context line explaining why agent wants this

### Context Generation

**Option: Hook for context generation**

Allow users to configure a hook that provides context for approval requests:

```json
{
  "claudeAgents.approvalContextHook": "node .opus-orchestra/context-hook.js"
}
```

Hook receives:
```json
{
  "type": "bash",
  "command": "npm install lodash",
  "agentId": "agent-1",
  "recentOutput": "...last 500 chars of terminal..."
}
```

Hook returns:
```json
{
  "context": "Adding lodash for deep clone in user service",
  "risk": "low",
  "suggestion": "approve"
}
```

**Option: AI subagent for context**

Settings UI:
```
┌─────────────────────────────────────────────────────────┐
│ Approval Context                                        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ Context Source:                                         │
│ ○ None (show request only)                              │
│ ○ Custom hook                                           │
│   Path: [.opus-orchestra/context.js____] [Browse]       │
│ ● AI Analysis (uses Claude to explain request)         │
│   Model: [claude-haiku ▼] (fast, cheap)                │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

The AI context generator:
1. Receives the pending request + recent terminal output
2. Uses a fast model (Haiku) to generate a one-line explanation
3. Optionally assesses risk level
4. Displayed in approval card

### Time-Since-Event Status

Instead of showing duration or branch:

```
● Working for 12m     (green dot, time since last output)
○ Waiting for 3m      (yellow dot, time since started waiting)
⏸ Idle                (gray, no active task)
```

Time updates live. "Working" means producing output, "Waiting" means awaiting approval or user input.

### Terminal Output Viewer

Better terminal output display in dashboard:

```
┌─────────────────────────────────────────────────────────┐
│ Agent-1 Output                          [Pop Out] [↻]  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ > Analyzing src/auth/jwt.ts...                         │
│ > Found potential security issue                        │
│ > Proposing fix for token validation                    │
│                                                         │
│ I'll update the token validation to check expiration.  │
│ Let me make these changes...                           │
│                                                         │
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ Waiting for approval   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

Keep it simple - just recent output, no complex features. "Pop Out" opens full terminal.

### Unified Settings Panel

All settings in one place with tabs:

```
┌─────────────────────────────────────────────────────────┐
│ Opus Orchestra Settings                                 │
├─────────────────────────────────────────────────────────┤
│ [General] [Profiles] [GitHub] [Containers] [Backlog]   │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ General Settings                                        │
│ ─────────────────────────────────────────────────────── │
│                                                         │
│ Default agent count:  [3____]                           │
│ Worktree directory:   [.worktrees____________]          │
│ Claude command:       [claude________________]          │
│ Terminal type:        [WSL ▼]                          │
│ UI Scale:             [1.0 ▼]                          │
│                                                         │
│ ─────────────────────────────────────────────────────── │
│                                                         │
│ Approval Context:                                       │
│ ○ None  ○ Custom hook  ● AI Analysis                   │
│                                                         │
│ ─────────────────────────────────────────────────────── │
│                                                         │
│ [✓] Auto-start Claude when creating terminal           │
│ [✓] Show notifications for pending approvals           │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Keyboard Navigation

**Dashboard shortcuts**:
| Key | Action |
|-----|--------|
| `j/k` | Next/previous agent |
| `Enter` | Focus selected agent's terminal |
| `a` | Approve pending (if any) |
| `x` | Deny pending |
| `n` | New agent |
| `?` | Show keyboard shortcuts |

### Status Bar

Simple status bar:

```
[🤖 3 agents | ⚠ 2 pending]
```

Click opens dashboard.

### Notification Improvements

**Toast notifications**:
```
┌─────────────────────────────────────────┐
│ Agent-2 needs approval                  │
│ Bash: npm install lodash                │
│ [Approve] [Deny] [View]                 │
└─────────────────────────────────────────┘
```

Allow quick approve/deny from notification without opening dashboard.

### Implementation Steps

1. **Agent Card Redesign**:
   - New layout with grouped buttons
   - Delete in corner
   - Prominent approval section
   - Time-since-event status
2. **Approval Section**:
   - Distinct visual styling
   - Large action buttons
   - Context display area
3. **Context Generation**:
   - Hook system for custom context
   - AI subagent option
   - Settings UI for configuration
4. **Terminal Viewer**:
   - Simple output display
   - Pop-out button
   - Refresh button
5. **Settings Panel**:
   - Tabbed interface
   - Consolidate all settings
6. **Keyboard Navigation**:
   - Focus management
   - Shortcut handler
7. **Status Bar**:
   - Agent count + pending count
   - Click handler
8. **Notifications**:
   - Action buttons in toast
   - Quick approve/deny

## Open Questions

1. **Context AI cost**: Charge per-request or bundle?
2. **Hook timeout**: How long to wait for hook response?
3. **Multiple pending**: Show all or just first?

## Dependencies

- Core dashboard exists (already implemented)
- VS Code webview API
- Optional: Claude API for AI context

## Risks

- Context generation latency → show "loading" state
- Hook errors → graceful fallback to no context
- Over-notification → respect user preferences
