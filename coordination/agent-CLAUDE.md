# Claude Agent Instructions

You are a Claude agent working as part of a multi-agent team on this codebase. Follow these instructions for task coordination.

## Your Identity

Your agent name is your git branch name. Check it with:
```bash
git branch --show-current
```

## Getting Started

1. **Check if you have a claimed task**:
   ```bash
   ./.claude-agents/task-claimer.sh my-task $(git branch --show-current)
   ```

2. **If no task, claim one**:
   ```bash
   # See available tasks
   ./.claude-agents/task-claimer.sh list-available

   # Claim a task
   ./.claude-agents/task-claimer.sh claim <task-name> $(git branch --show-current)
   ```

3. **Read your task file**: `.claude-agents/backlog/<task-name>.md`

4. **Work through the implementation plan** in the task file

## When You Finish a Task

1. Ensure all checklist items in the task file are complete
2. Run tests if applicable
3. Commit your changes
4. Mark the task complete:
   ```bash
   ./.claude-agents/task-claimer.sh complete <task-name> $(git branch --show-current)
   ```
5. Claim your next task or wait for assignment

## Slash Commands

Use these commands for quick task operations:

- `/claim <task-name>` - Claim a specific task
- `/complete` - Mark your current task as complete
- `/tasks` - List available tasks
- `/my-task` - Show your currently claimed task

## Rules

1. **Always claim before working** - Never start without claiming first
2. **One task at a time** - Complete or release before taking another
3. **Use the script** - Don't manually edit coordination files
4. **Commit often** - Make your progress visible via git

## If You're Stuck

- Ask for clarification via your terminal
- Release the task if you can't complete it:
  ```bash
  ./.claude-agents/task-claimer.sh release <task-name> $(git branch --show-current)
  ```

## File Structure

```
.claude-agents/
├── CLAUDE.md           # This file
├── task-claimer.sh     # Coordination script (DO NOT MODIFY)
├── claims.jsonl        # Claim log (DO NOT MODIFY)
├── backlog/            # Task files (symlink)
└── completed/          # Finished tasks
```
