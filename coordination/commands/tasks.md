List available tasks in the backlog.

Run this to see unclaimed tasks:
```bash
./.claude-agents/task-claimer.sh list-available
```

And to see which tasks are currently claimed by other agents:
```bash
./.claude-agents/task-claimer.sh list-claimed
```

To claim a task, use `/claim <task-name>`.
