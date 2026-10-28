---
name: git-branch-pr
description: >-
  Automates creating a new Git branch, committing staged/unstaged changes,
  pushing to the remote origin, and creating a GitHub Pull Request via the
  GitHub CLI (`gh`) or web URL fallback. Use whenever the user asks to create a
  new branch, push and open a pull request, create a PR, submit changes for
  review, or package work into a branch and PR.
---

# Git Branch, Push & Pull Request Workflow

This skill guides the agent through safely creating a dedicated feature or bugfix branch, staging and committing working tree changes, pushing to the remote repository, and opening a comprehensive GitHub Pull Request.

---

## Workflow Overview

```
1. Pre-Flight Checks ➔ 2. Branch Creation ➔ 3. Commit Changes ➔ 4. Push Upstream ➔ 5. Open Pull Request ➔ 6. Verify & Report
```

---

## Step-by-Step Procedure

### 1. Pre-Flight Checks

Before creating branches or pushing, verify the local and remote environment:

1. **Verify Git Remote**:
   ```bash
   git remote -v
   ```
   Ensure `origin` points to the expected repository.

2. **Check Base Branch & Sync**:
   Determine the default base branch (`main` or `master`):
   ```bash
   git remote show origin
   # or
   git symbolic-ref refs/remotes/origin/HEAD
   ```

3. **Check Working Tree State**:
   ```bash
   git status -s
   ```
   Review modified, added, and untracked files. Exclude temporary files, logs, or secrets before proceeding.

4. **Check GitHub CLI Authentication**:
   ```bash
   gh auth status
   ```
   - If authenticated: proceed to use `gh pr create`.
   - If not authenticated or `gh` is missing: fall back to generating a GitHub comparison URL for manual submission.

---

### 2. Create and Switch to a New Branch

1. **Determine Branch Name**:
   Follow semantic branch naming conventions:
   - `feat/<short-description>`: New feature or major capability
   - `fix/<short-description>`: Bugfix or defect resolution
   - `refactor/<short-description>`: Code restructuring or architecture cleanup
   - `docs/<short-description>`: Documentation updates
   - `chore/<short-description>`: Build, tooling, dependencies, or maintenance

   *Example*: `feat/afk-facility-gameplay-loop`

2. **Branch Creation**:
   - If branching from the current dirty working tree:
     ```bash
     git checkout -b <branch-name>
     ```
   - If branching from updated base branch (`main`/`master`):
     ```bash
     git fetch origin
     git checkout -b <branch-name> origin/main
     ```

---

### 3. Stage and Commit Changes

1. **Review and Stage Files**:
   Stage relevant tracked and untracked files:
   ```bash
   git add <file1> <file2> ...
   # Or stage all relevant files avoiding build artifacts:
   git add src/
   ```

2. **Format Commit Message**:
   Follow the [Conventional Commits](references/pr-templates.md) specification:
   ```
   <type>(<scope>): <short imperative summary>

   <detailed description of changes>
   ```

   *Example*:
   ```bash
   git commit -m "feat(facility): implement afk gameplay loop and outskirts facilities"
   ```

---

### 4. Push Branch Upstream

Push the newly created branch to `origin` and configure upstream tracking:

```bash
git push -u origin <branch-name>
```

If the remote branch already exists and tracking is set:
```bash
git push
```

---

### 5. Create Pull Request

#### Option A: Using GitHub CLI (`gh`) (Preferred)

Use the helper script [create_pr.ps1](scripts/create_pr.ps1) (Windows) or [create_pr.sh](scripts/create_pr.sh) (macOS/Linux), or run `gh pr create` directly:

```bash
gh pr create --base <base-branch> --head <branch-name> --title "<PR Title>" --body "<PR Body Markdown>"
```

**Recommended PR Body Structure**:
```markdown
## Summary
Concise description of the purpose and context of this Pull Request.

## Key Changes
- **Module A**: Description of change.
- **Module B**: Description of change.

## Verification & Testing
- [x] Unit/integration tests executed and passed.
- [x] Tested in live environment / game client.

## Related Issues
Closes #<issue-number> (if applicable)
```

For more templates, see [PR Templates](references/pr-templates.md).

#### Option B: Web Fallback (If `gh` is unavailable)

If `gh` is not installed or unauthenticated:
1. Extract remote origin URL:
   ```bash
   git config --get remote.origin.url
   ```
2. Construct the compare URL:
   `https://github.com/<owner>/<repo>/compare/<base-branch>...<branch-name>?expand=1`
3. Provide the formatted title, body, and URL to the user to open in their browser.

---

### 6. Verify and Report

1. Display the created Pull Request URL (e.g., `https://github.com/owner/repo/pull/123`).
2. Confirm the branch status:
   ```bash
   git status
   ```
3. Report a clear summary back to the user with clickable links to the PR and branch.
