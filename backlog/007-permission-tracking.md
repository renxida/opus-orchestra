# Permission Request Tracking

## Summary

Track and analyze permission requests across agents to identify patterns and suggest efficiency improvements through broader permissions.

## Motivation

In manual approval mode, users repeatedly approve similar operations:
- "Allow write to src/components/Button.tsx" (approved 50 times)
- "Allow npm test" (approved 100 times)
- "Allow read from package.json" (approved every session)

This is tedious and doesn't improve over time. By tracking permission requests, we can:
- Show users what they're approving most often
- Suggest permissions to allow broadly
- Identify patterns per project/agent type
- Improve efficiency without sacrificing security awareness

## Design

### Permission Log

Store every permission request and decision:

```json
{
  "timestamp": "2024-12-10T14:30:52Z",
  "agentId": "agent-1",
  "agentProfile": ["conservative", "frontend-dev"],
  "request": {
    "type": "fileWrite",
    "target": "src/components/Button.tsx",
    "context": "Updating button styles"
  },
  "decision": "allow",
  "decisionType": "manual",
  "responseTime": 3200
}
```

### Analytics Dashboard

**Permission Insights Panel**:
```
┌─────────────────────────────────────────────────────────┐
│ Permission Insights                    [Last 7 days ▼] │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ Overview:                                               │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Total Requests: 847                                 │ │
│ │ Manually Approved: 612 (72%)                        │ │
│ │ Auto-Approved: 201 (24%)                            │ │
│ │ Denied: 34 (4%)                                     │ │
│ │                                                     │ │
│ │ Avg Response Time: 4.2s                             │ │
│ │ Time Spent Approving: ~43 min                       │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ Most Frequent (manually approved):                      │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ #  Request                           Count  Action  │ │
│ │ 1. Write src/components/*.tsx         156   [Allow] │ │
│ │ 2. Bash: npm test                      89   [Allow] │ │
│ │ 3. Bash: npm install *                 67   [Allow] │ │
│ │ 4. Write src/styles/*.css              45   [Allow] │ │
│ │ 5. Read package.json                   42   [Allow] │ │
│ │ 6. Bash: git status                    38   [Allow] │ │
│ │ 7. Write src/api/*.ts                  31   [Allow] │ │
│ │ 8. Bash: npm run build                 28   [Allow] │ │
│ │ ...                                                 │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ Suggested Auto-Approvals:                               │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Based on your patterns, consider allowing:          │ │
│ │                                                     │ │
│ │ [✓] Write(src/components/*.tsx)                     │ │
│ │     156 requests, 0 denials                         │ │
│ │                                                     │ │
│ │ [✓] Bash(npm test)                                  │ │
│ │     89 requests, 0 denials                          │ │
│ │                                                     │ │
│ │ [ ] Bash(npm install *)                             │ │
│ │     67 requests, 2 denials (review recommended)     │ │
│ │                                                     │ │
│ │                      [Apply Selected] [Dismiss]     │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Pattern Detection

**Grouping Logic**:
- Exact matches: `npm test` → `npm test`
- Glob patterns: `src/components/Button.tsx`, `src/components/Card.tsx` → `src/components/*.tsx`
- Command patterns: `npm install lodash`, `npm install react` → `npm install *`

**Confidence Scoring**:
```
Score = (approvals - denials * 10) / total_requests

High confidence (>0.95): Safe to suggest auto-approval
Medium confidence (0.8-0.95): Suggest with warning
Low confidence (<0.8): Don't suggest
```

### Settings Integration

**Quick Actions from Insights**:
- "Allow" button adds permission to current profile
- "Allow for project" adds to `.opus-orchestra/config.json`
- "Allow globally" adds to VS Code user settings

**Permission Rule Builder**:
```
┌─────────────────────────────────────────────────────────┐
│ Add Permission Rule                                     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ Type: [File Write ▼]                                    │
│                                                         │
│ Pattern: [src/components/*.tsx_______]                  │
│                                                         │
│ Based on: 156 past approvals                            │
│                                                         │
│ Scope:                                                  │
│ ○ This agent only                                       │
│ ○ Agents with profile: [frontend-dev ▼]                │
│ ● This project (all agents)                            │
│ ○ Global (all projects)                                 │
│                                                         │
│                              [Cancel]  [Add Rule]       │
└─────────────────────────────────────────────────────────┘
```

### Time Analysis

Track time spent on approvals:

```
┌─────────────────────────────────────────────────────────┐
│ Approval Time Analysis                                  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ This Week:                                              │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ ████████████████████░░░░░░░░░░  43 min approving    │ │
│ │                                                     │ │
│ │ If you auto-approved top 5 patterns:                │ │
│ │ ████████░░░░░░░░░░░░░░░░░░░░░░  12 min (-72%)       │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ Breakdown by type:                                      │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ File Write:  ████████████████  28 min               │ │
│ │ Bash:        ████████          12 min               │ │
│ │ File Read:   ██                 3 min               │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Per-Agent History

View permission history for specific agent:

```
┌─────────────────────────────────────────────────────────┐
│ Agent-1 Permission History                              │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ Session: Dec 10, 2024 2:00 PM - 3:30 PM                │
│                                                         │
│ 2:05 PM  Write src/Button.tsx          [Approved]      │
│ 2:08 PM  Bash: npm test                [Approved]      │
│ 2:15 PM  Write src/Card.tsx            [Approved]      │
│ 2:18 PM  Bash: rm -rf node_modules     [DENIED]        │
│ 2:20 PM  Bash: npm install             [Approved]      │
│ ...                                                     │
│                                                         │
│ Summary: 45 approved, 2 denied                          │
│                                                         │
│ [Export Log]  [Clear History]                           │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Storage

**Local Storage** (per-workspace):
```
.opus-orchestra/
└── analytics/
    ├── permissions.jsonl      # Append-only log
    ├── patterns.json          # Detected patterns
    └── suggestions.json       # Generated suggestions
```

**Format** (JSONL for append efficiency):
```jsonl
{"ts":"2024-12-10T14:30:52Z","agent":"agent-1","type":"fileWrite","target":"src/Button.tsx","decision":"allow"}
{"ts":"2024-12-10T14:31:05Z","agent":"agent-1","type":"bash","target":"npm test","decision":"allow"}
```

### Privacy Considerations

- All data stored locally
- No telemetry sent externally
- Option to disable tracking
- Clear history command available

### Implementation Steps

1. **Permission Logger**:
   - Hook into approval flow
   - Log all requests with metadata
   - Append to JSONL file
2. **Pattern Analyzer**:
   - Read permission log
   - Group similar requests
   - Generate glob patterns
   - Calculate confidence scores
3. **Insights UI**:
   - Dashboard panel/tab
   - Frequency charts
   - Time analysis
   - Suggestion cards
4. **Quick Actions**:
   - "Allow" buttons that update config
   - Scope selection (agent/project/global)
   - Undo functionality
5. **Per-Agent History**:
   - Timeline view
   - Export capability
   - Clear history option
6. **Settings**:
   - Enable/disable tracking
   - Retention period
   - Pattern sensitivity

## Open Questions

1. **Retention**: How long to keep permission logs?
2. **Cross-project learning**: Share patterns between projects?
3. **Smart suggestions**: ML-based pattern detection vs rule-based?

## Dependencies

- Agent configuration (see 006-agent-configuration.md) for applying suggested rules
- Permission system hooks in agentManager

## Risks

- Large log files → implement rotation/compaction
- Stale patterns → time-weight recent data higher
- Over-permissive suggestions → require denial analysis
