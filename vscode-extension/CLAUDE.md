# Claude Code Notes - Agent Workflow VS Code Extension

## Project Overview

A VS Code extension for managing multiple Claude Code agents working in parallel on git worktrees. Each agent gets its own worktree, terminal, and Claude session.

## Critical Path Handling - MUST READ

### The Problem

This extension runs in **VS Code on Windows** (Windows Node.js) but executes commands in **WSL terminals**. This creates a fundamental path conversion problem:

1. Windows Node.js `path.join()` uses backslashes
2. Windows Node.js `fs` module needs Windows-style paths (`C:/...`)
3. Terminal commands need WSL-style paths (`/mnt/c/...`)

### The Solution: AgentPath Class

**ALWAYS use the `AgentPath` class for path operations.** Never use raw `path.join()` for cross-platform paths.

```typescript
import { agentPath } from './pathUtils';

// Create an AgentPath from any format (WSL, Windows, Git Bash)
const p = agentPath(agent.worktreePath);

// For Node.js fs operations (existsSync, readFileSync, etc.)
const statusDir = p.join('.claude-agents', 'status').forNodeFs();
//   → Returns: C:/Users/Kyle/project/.claude-agents/status

// For terminal commands (sent to WSL/Git Bash/PowerShell)
const termPath = p.forTerminal();
//   → Returns: /mnt/c/Users/Kyle/project (for WSL)

// For display to users
const displayPath = p.forDisplay();
//   → Returns: C:\Users\Kyle\project
```

### Path Formats Reference

| Context | Format | Example |
|---------|--------|---------|
| Node.js fs operations | `C:/...` (forward slashes work) | `C:/Users/Kyle/project` |
| WSL terminal commands | `/mnt/c/...` | `/mnt/c/Users/Kyle/project` |
| Git Bash commands | `/c/...` | `/c/Users/Kyle/project` |
| PowerShell/CMD | `C:\...` | `C:\Users\Kyle\project` |

### Common Path Bugs - DO NOT MAKE THESE MISTAKES

**BUG 1: Using path.join() for WSL paths**
```typescript
// WRONG - Windows Node.js path.join() uses backslashes!
path.join('/mnt/c/Users/Kyle', 'subdir')
// Returns: \mnt\c\Users\Kyle\subdir (BROKEN!)

// CORRECT - Use template strings or AgentPath
`${worktreePath}/.claude-agents/status`
// OR
agentPath(worktreePath).join('.claude-agents', 'status').forNodeFs()
```

**BUG 2: Using WSL paths with Windows Node.js fs module**
```typescript
// WRONG - Windows Node.js can't read /mnt/c/... paths!
const exists = fs.existsSync('/mnt/c/Users/Kyle/file');
// Returns: false (even if file exists!)

// CORRECT - Convert to Windows format for fs operations
const exists = fs.existsSync(agentPath('/mnt/c/Users/Kyle/file').forNodeFs());
// Checks: C:/Users/Kyle/file
```

**BUG 3: Mixing path formats**
```typescript
// WRONG - toWindowsPath returns C:\..., then joining creates mixed paths
const windowsPath = this.toWindowsPath(agent.worktreePath);  // C:\Users\Kyle
const statusDir = `${windowsPath}/.claude-agents/status`;    // C:\Users\Kyle/.claude-agents/status (BROKEN!)

// CORRECT - Use AgentPath consistently
const statusDir = agentPath(agent.worktreePath).join('.claude-agents', 'status').forNodeFs();
```

### Helper Methods in AgentManager

The `toTerminalPath()` and `toWindowsPath()` methods are thin wrappers around AgentPath:

```typescript
// These exist for backward compatibility but use AgentPath internally
toTerminalPath(inputPath)  → agentPath(inputPath).forTerminal()
toWindowsPath(inputPath)   → agentPath(inputPath).forNodeFs()
```

## Hook System

### How Status Tracking Works

1. Hooks in `.claude/settings.json` fire on Claude events (Stop, PermissionRequest, etc.)
2. Hook scripts write status to `.claude-agents/status/{session_id}`
3. Extension polls status directory, reads most recent file by mtime
4. Dashboard updates to show agent status

### Session ID Mismatch

The extension generates a session ID when creating an agent, but Claude may use a different session ID. Solution: scan ALL files in the status directory and use the most recently modified one.

### Hook Events Used

- `UserPromptSubmit` → writes "working" status
- `Stop` → writes "waiting" status
- `SessionEnd` → writes "stopped" status
- `PermissionRequest` → writes JSON with tool name and context

## Agent Naming

Agents use NATO phonetic alphabet names: alpha, bravo, charlie, etc.
- Branch: `claude-{name}` (e.g., `claude-alpha`)
- Worktree: `.worktrees/claude-{name}/`
- Display name: Just `{name}` (e.g., `alpha`)

## Testing

Run tests: `npm run compile && npx mocha --ui tdd ./out/test/suite/agentPanel.test.js`

Tests verify:
- Button data-action attributes match switch case handlers
- All buttons have corresponding message handlers
- Agent cards have required elements (inline rename input, etc.)

## Build & Install

```bash
./compile_and_install.sh  # Compiles, packages, installs to Windows VS Code
```

## File Structure

- `src/pathUtils.ts` - **AgentPath class** - USE THIS FOR ALL PATH OPERATIONS
- `src/agentManager.ts` - Agent lifecycle, terminal management, git operations
- `src/agentPanel.ts` - Dashboard webview with agent cards
- `src/extension.ts` - Extension activation, commands, polling intervals
- `coordination/` - Bundled hooks and slash commands copied to worktrees

## Debugging

### Debug Logging

`console.log()` output is NOT accessible from VS Code extensions. Use the `debugLog()` method instead:

```typescript
this.debugLog(`[methodName] variable: ${value}`);
```

This writes to `debug.log` in the **installed extension directory** (not the source directory):
```bash
# Find the installed extension path first
ls /mnt/c/Users/Kyle/.vscode/extensions/ | grep claude-agents

# Then view the log
cat "/mnt/c/Users/Kyle/.vscode/extensions/your-publisher-id.claude-agents-X.Y.Z/debug.log"

# Or tail -f for live monitoring
tail -f "/mnt/c/Users/Kyle/.vscode/extensions/your-publisher-id.claude-agents-X.Y.Z/debug.log"
```

Remember to remove debug logging before committing.

## Common Gotchas

### Webview Limitations
- `confirm()` and `prompt()` don't work in VS Code webviews - use `vscode.window.showWarningMessage()` or inline inputs
- Use event delegation with data attributes instead of inline onclick handlers
- Call `acquireVsCodeApi()` only once (use IIFE guard)

### Permission Prompts Vary
Claude's permission prompts have different options for different tools:
- File edits: 1=Allow, 2=Always, 3=Reject, 4=Never
- Bash: 1=Yes, 2=Yes for this type, 3=Text input

Don't hardcode specific reject buttons - use "Respond..." to focus terminal instead.

### Terminal Names on Reload
VS Code terminals may have empty names (`""`) after reload, making it impossible to reconnect agents to existing terminals. This is a known issue - terminals need to be recreated.
