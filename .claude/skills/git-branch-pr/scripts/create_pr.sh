#!/usr/bin/env bash
# create_pr.sh - Creates a new branch, commits, pushes, and opens a GitHub PR.
set -euo pipefail

BRANCH_NAME="${1:-}"
COMMIT_MSG="${2:-}"
PR_TITLE="${3:-}"
PR_BODY="${4:-}"
BASE_BRANCH="${5:-}"

if [[ -z "$BRANCH_NAME" ]]; then
  echo "Usage: $0 <branch_name> [commit_message] [pr_title] [pr_body] [base_branch]"
  exit 1
fi

# Detect base branch if not provided
if [[ -z "$BASE_BRANCH" ]]; then
  BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
fi

echo "==> Target base branch: $BASE_BRANCH"

# Checkout or create branch
CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" != "$BRANCH_NAME" ]]; then
  if git show-ref --quiet --heads "$BRANCH_NAME"; then
    echo "==> Switching to existing branch '$BRANCH_NAME'..."
    git checkout "$BRANCH_NAME"
  else
    echo "==> Creating and switching to new branch '$BRANCH_NAME'..."
    git checkout -b "$BRANCH_NAME"
  fi
fi

# Commit dirty changes if present
if [[ -n $(git status --porcelain) ]]; then
  if [[ -z "$COMMIT_MSG" ]]; then
    COMMIT_MSG="chore: update changes for $BRANCH_NAME"
  fi
  echo "==> Staging and committing changes..."
  git add .
  git commit -m "$COMMIT_MSG"
fi

# Push branch to remote
echo "==> Pushing to origin/$BRANCH_NAME..."
git push -u origin "$BRANCH_NAME"

# Create PR via gh CLI or fallback
if command -v gh >/dev/null 2>&1; then
  echo "==> Creating Pull Request via gh..."
  TITLE="${PR_TITLE:-$BRANCH_NAME}"
  if [[ -n "$PR_BODY" ]]; then
    gh pr create --base "$BASE_BRANCH" --head "$BRANCH_NAME" --title "$TITLE" --body "$PR_BODY"
  else
    gh pr create --base "$BASE_BRANCH" --head "$BRANCH_NAME" --title "$TITLE" --fill
  fi
else
  REMOTE_URL=$(git config --get remote.origin.url)
  echo "==> 'gh' CLI not found. Remote: $REMOTE_URL"
  echo "Please open a PR manually via GitHub web."
fi
