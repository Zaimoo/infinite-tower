---
name: git-push-and-pull
description: >-
  Use this skill when the user wants to pull latest changes from the remote repository,
  sync with local changes, create a new branch, push the branch to remote, and create
  a pull request.
---

# Git Push and Pull

This skill defines the standardized workflow to pull the latest remote changes, synchronize local modifications, branch off cleanly, push commits, and open a pull request.

## Workflow Steps

### 1. Check Working Tree & Save In-Progress Changes
Check the current branch and repository status:
```powershell
git status
```
If there are uncommitted modifications or untracked files that need to be preserved before switching or pulling:
```powershell
git stash push -u -m "WIP before syncing with latest"
```

### 2. Fetch and Update the Base Branch
Fetch the latest commits from remote:
```powershell
git fetch origin
```
Switch to the primary base branch (usually `main` or `master`) and pull the latest changes:
```powershell
git checkout main
git pull origin main
```

### 3. Create or Rebase Feature Branch
Create a new feature or chore branch from the updated base branch:
```powershell
git checkout -b <branch-type>/<short-description>
```
*Naming convention examples:* `feat/my-feature`, `fix/issue-description`, `chore/task-name`.

If changes were stashed in Step 1, restore them:
```powershell
git stash pop
```
*(If merge conflicts occur, resolve them before proceeding).*

### 4. Stage and Commit
Review modified and added files:
```powershell
git status
```
Stage relevant files and create a structured commit:
```powershell
git add <files>
git commit -m "<type>(<scope>): <concise summary of changes>"
```

### 5. Push to Remote
Push the branch to origin and configure tracking:
```powershell
git push -u origin <branch-type>/<short-description>
```

### 6. Create a Pull Request
If GitHub CLI (`gh`) is installed and authenticated:
```powershell
gh pr create --base main --head <branch-name> --title "<PR Title>" --body "<PR Description>"
```

If `gh` CLI is not available:
* Use the direct Pull Request URL printed by Git or construct the URL:
  `https://github.com/<owner>/<repo>/compare/main...<branch-name>?expand=1`
* Provide this link to the user along with a suggested PR title and body.
