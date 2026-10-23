# Pull Request Templates & Conventional Commits

## Conventional Commits Reference

Format: `<type>(<optional scope>): <description>`

Common types:
- `feat`: A new feature (e.g. `feat(facility): add outskirts guard post and afk economy`)
- `fix`: A bug fix (e.g. `fix(combat): resolve stamina recovery formula in infirmary`)
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `perf`: A code change that improves performance
- `style`: Formatting, semicolons, whitespace changes
- `test`: Adding missing tests or correcting existing tests
- `chore`: Updating build tasks, tooling, package configs
- `docs`: Documentation only changes

---

## PR Body Markdown Templates

### 1. Feature PR Template
```markdown
## Summary
Implemented [feature name], introducing [brief high-level summary of capabilities].

## Motivation / Context
Fulfills requirements from [Game Design Doc / Issue #XYZ]. Enables [gameplay mechanic / user value].

## Key Changes
- **Architecture / Config**: Added configuration tables and balance parameters.
- **Service Layer**: Implemented server-authoritative state transitions and lifecycle handlers.
- **Client / UI**: Created modal screens and rendering loops with responsive styling.

## Verification & Testing
- [x] Static type checking and compiler validations passed with 0 errors.
- [x] Unit test suites executed and verified.
- [x] In-engine / in-client playtesting completed.

## Screenshots / Media (Optional)
<!-- Attach screenshots or clips if applicable -->
```

### 2. Bugfix PR Template
```markdown
## Summary
Fixes [issue description] where [symptom or error occurred].

## Root Cause
[Brief explanation of why the bug occurred].

## Resolution
[Description of the fix implemented].

## Testing & Verification
- [x] Reproduced issue prior to fix.
- [x] Verified fix resolves the bug without regressions.
```
