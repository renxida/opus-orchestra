# Task Format and Dependencies

## Summary

A standardized task format with support for dependencies, categories, and metadata. Includes tooling to generate task scaffolds that humans or AI ideators can fill in, reducing manual boilerplate.

## Motivation

Without a consistent task format:
- Conductor can't reliably parse tasks
- Dependencies aren't tracked
- Categories are inconsistent
- Progress tracking is manual

A structured format with generation tooling enables:
- Consistent task structure without manual boilerplate
- Automated dependency resolution
- Category-based grouping and assignment
- Status tracking

## Design

### Task Generation Tool

Instead of requiring manual frontmatter creation, provide a tool that generates task scaffolds:

**Command Palette**: "Opus Orchestra: Create New Task"

**Quick Create Dialog**:
```
┌─────────────────────────────────────────────────────────┐
│ Create New Task                                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ Title: [Add user authentication________________]        │
│                                                         │
│ Quick Options:                                          │
│ Priority: [medium ▼]   Category: [backend ▼] [+ more]  │
│                                                         │
│                         [Create & Edit]  [Create]       │
└─────────────────────────────────────────────────────────┘
```

**Generated Task** (`backlog/task-20241210-143052-add-user-auth.md`):
```markdown
---
id: task-20241210-143052
title: Add user authentication
status: available
priority: medium
category: [backend]
depends_on: []
blocks: []
estimated_files: []
created: 2024-12-10T14:30:52Z
---

# Add user authentication

## Description

<!-- Describe the task in detail -->

## Acceptance Criteria

- [ ] <!-- Criterion 1 -->
- [ ] <!-- Criterion 2 -->

## Technical Notes

<!-- Optional: implementation hints, relevant files, etc. -->
```

**ID Generation**:
- Local tasks: `task-{timestamp}` or `task-{timestamp}-{slug}`
- GitHub issues: `issue-{number}`
- Custom source: `{source}-{external-id}`

This avoids collisions and provides clear provenance.

### Minimal Required Fields

Only require what's essential:
- `id`: Auto-generated
- `title`: User provides
- `status`: Defaults to "available"

Everything else is optional and can be filled in later:
- `priority`: Default "medium"
- `category`: Empty array
- `depends_on`: Empty array
- `blocks`: Empty array
- `estimated_files`: Empty array
- `created`: Auto-set

### AI Ideator Integration

The task scaffold is designed for AI ideators (planning agents) to fill in:

**Ideator Workflow**:
1. Human creates scaffold with just a title
2. Ideator agent reads task and expands:
   - Writes detailed description
   - Adds acceptance criteria
   - Suggests categories based on description
   - Identifies dependencies if related tasks exist
   - Estimates affected files
3. Human reviews and approves
4. Conductor assigns to worker agent

**Ideator-Friendly Format**:
- Clear HTML comments show where to fill in
- Sections are optional - ideator can skip what's not relevant
- Frontmatter is machine-parseable, body is freeform markdown

### Task Format

```markdown
---
id: task-20241210-143052
title: Fix authentication bypass vulnerability
status: available
priority: high
category: [security, backend]
depends_on: [task-20241210-120000]
blocks: []
estimated_files: [src/auth/*]
created: 2024-12-10T14:30:52Z
---

# Fix authentication bypass vulnerability

## Description

The current JWT validation doesn't check token expiration properly.

## Acceptance Criteria

- [ ] Token expiration is validated
- [ ] Expired tokens return 401
- [ ] Tests added

## Technical Notes

Check src/auth/jwt.ts for current logic.
```

### Field Definitions

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `id` | auto | generated | Unique identifier |
| `title` | yes | - | Short descriptive title |
| `status` | auto | available | available, assigned, in-progress, blocked, completed |
| `priority` | no | medium | critical, high, medium, low |
| `category` | no | [] | Categories/tags for grouping |
| `depends_on` | no | [] | Task IDs this depends on |
| `blocks` | no | [] | Task IDs blocked by this |
| `estimated_files` | no | [] | Glob patterns for files likely touched |
| `created` | auto | now | Creation timestamp |

### Flexible Parsing

The parser should be lenient:
- Missing optional fields → use defaults
- Unknown fields → preserve them (extensibility)
- Malformed frontmatter → warn but still show task
- No frontmatter → treat entire file as description, generate ID from filename

This avoids fragility when tasks are hand-edited or come from different sources.

### Status Workflow

```
available → assigned → in-progress → completed
                 ↓           ↓
              blocked    cancelled
```

Status is primarily informational. The conductor and agents update it, but invalid transitions don't break anything.

### Dependency Management

**Soft Dependencies**:
- Dependencies are hints for the conductor
- Blocked tasks are still visible, just marked
- No hard enforcement - conductor uses judgment

**UI Display**:
```
┌─────────────────────────────────────────────────────────┐
│ Dependencies                                            │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ This task:  Fix authentication bypass                   │
│                                                         │
│ Depends on:                                             │
│   └─ task-20241210-120000: Setup auth module [done ✓]  │
│                                                         │
│ Blocks:                                                 │
│   ├─ issue-42: Add OAuth support [waiting]             │
│   └─ task-20241210-150000: Security audit [waiting]    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Category Settings

**Settings UI**:
```
┌─────────────────────────────────────────────────────────┐
│ Task Categories                                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ Category      Color    Suggested File Patterns          │
│ ─────────────────────────────────────────────────────── │
│ frontend      🟦       src/components/*, *.css, *.tsx   │
│ backend       🟩       src/api/*, src/server/*          │
│ database      🟨       src/db/*, migrations/*           │
│ security      🟥       src/auth/*, src/crypto/*         │
│ tests         🟪       **/*.test.*, **/*.spec.*         │
│ docs          ⬜       docs/*, *.md                      │
│                                                         │
│ [+ Add Category]                                        │
│                                                         │
│ [✓] Suggest categories based on estimated_files        │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

Categories help the conductor avoid overlap. File patterns let the ideator auto-suggest categories.

### Task Editor UI

For editing existing tasks:

```
┌─────────────────────────────────────────────────────────┐
│ Edit Task                                    [Save] [×] │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ Title: [Fix authentication bypass__________________]    │
│                                                         │
│ Status: [in-progress ▼]  Priority: [high ▼]            │
│                                                         │
│ Categories: [security ×] [backend ×] [+ Add]           │
│                                                         │
│ Depends on: [task-20241210-120000 ×] [+ Add]          │
│ Blocks:     [issue-42 ×] [+ Add]                       │
│                                                         │
│ Estimated files:                                        │
│ [src/auth/*] [src/middleware/auth.ts] [+ Add]          │
│                                                         │
│ Description:                                            │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ The current JWT validation doesn't check token      │ │
│ │ expiration properly...                              │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Implementation Steps

1. **Task Generator**:
   - Command to create new task with scaffold
   - Auto-generate ID from timestamp + slug
   - Create file in backlog directory
   - Optionally open for editing
2. **Flexible Parser**:
   - Parse YAML frontmatter (lenient)
   - Extract body as description
   - Handle missing/malformed data gracefully
   - Normalize different ID formats
3. **Task Writer**:
   - Update frontmatter while preserving body formatting
   - Handle partial updates (single field change)
4. **Category Manager**:
   - Settings UI for category definitions
   - File pattern → category suggestions
5. **Task Editor UI**:
   - Form for editing all fields
   - Dependency/blocks pickers
   - Category selector
6. **Ideator Support**:
   - Document expected format for AI planners
   - Example prompts for ideator agents

## File Naming

Tasks are files in the backlog directory:
- `task-{timestamp}-{optional-slug}.md`
- `issue-{number}.md` (from GitHub)
- `{custom-source}-{id}.md`

The ID is in the frontmatter and is authoritative. Filename is for human convenience.

## Open Questions

1. **Slug generation**: Auto from title, or let user specify?
2. **Archival**: Move completed tasks to `completed/` folder?
3. **Templates**: Different scaffolds for bug vs feature vs chore?

## Dependencies

- Backlog tooling (see 003-backlog-tooling.md)
- YAML parser library

## Risks

- Over-engineering → keep it simple, let ideators do the work
- Fragile parsing → be lenient, warn don't fail
- Manual burden → generate everything possible
