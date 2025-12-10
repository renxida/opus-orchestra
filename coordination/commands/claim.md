Claim a task from the backlog.

Task to claim: $ARGUMENTS

Run this command to claim the task:
```bash
./.claude-agents/task-claimer.sh claim "$ARGUMENTS" "$(git branch --show-current)"
```

After claiming, read the task file at `.claude-agents/backlog/$ARGUMENTS.md` and begin working on it.
