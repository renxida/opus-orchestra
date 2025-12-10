Check what task you currently have claimed.

```bash
./.claude-agents/task-claimer.sh my-task "$(git branch --show-current)"
```

If you have a task claimed, read it at `.claude-agents/backlog/<task-name>.md`.
