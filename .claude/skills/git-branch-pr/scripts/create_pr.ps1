<#
.SYNOPSIS
    Automates creating a new branch, staging, committing, pushing, and creating a GitHub PR.
.PARAMETER BranchName
    The name of the new branch to create (e.g., 'feat/afk-facility-loop').
.PARAMETER CommitMessage
    Commit message to use if there are uncommitted changes.
.PARAMETER Title
    The Pull Request title.
.PARAMETER Body
    The Pull Request description body.
.PARAMETER BaseBranch
    Target base branch (default: main).
.PARAMETER Draft
    Create the PR as a draft.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$BranchName,

    [Parameter(Mandatory = $false)]
    [string]$CommitMessage = "",

    [Parameter(Mandatory = $false)]
    [string]$Title = "",

    [Parameter(Mandatory = $false)]
    [string]$Body = "",

    [Parameter(Mandatory = $false)]
    [string]$BaseBranch = "",

    [Parameter(Mandatory = $false)]
    [switch]$Draft
)

$ErrorActionPreference = "Stop"

Write-Host "==> Checking Git repository status..." -ForegroundColor Cyan

# 1. Determine Base Branch if not provided
if (-not $BaseBranch) {
    try {
        $originHead = git symbolic-ref refs/remotes/origin/HEAD 2>$null
        if ($originHead) {
            $BaseBranch = ($originHead -split "/")[-1]
        } else {
            $BaseBranch = "main"
        }
    } catch {
        $BaseBranch = "main"
    }
}
Write-Host "Target Base Branch: $BaseBranch" -ForegroundColor Gray

# 2. Check if branch already exists
$currentBranch = (git branch --show-current).Trim()
if ($currentBranch -ne $BranchName) {
    $localBranchExists = git branch --list $BranchName
    if ($localBranchExists) {
        Write-Host "==> Switching to existing branch '$BranchName'..." -ForegroundColor Yellow
        git checkout $BranchName
    } else {
        Write-Host "==> Creating and switching to new branch '$BranchName'..." -ForegroundColor Green
        git checkout -b $BranchName
    }
} else {
    Write-Host "==> Already on target branch '$BranchName'." -ForegroundColor Gray
}

# 3. Check for unstaged/uncommitted changes
$status = git status --porcelain
if ($status) {
    if (-not $CommitMessage) {
        $CommitMessage = "chore: update changes for $BranchName"
    }
    Write-Host "==> Staging and committing changes..." -ForegroundColor Green
    git add .
    git commit -m $CommitMessage
} else {
    Write-Host "==> No uncommitted changes detected." -ForegroundColor Gray
}

# 4. Push upstream
Write-Host "==> Pushing branch '$BranchName' to origin..." -ForegroundColor Cyan
git push -u origin $BranchName

# 5. Create Pull Request using gh CLI if available
$ghAvailable = Get-Command gh -ErrorAction SilentlyContinue
if ($ghAvailable) {
    Write-Host "==> Creating Pull Request via GitHub CLI..." -ForegroundColor Cyan
    
    if (-not $Title) {
        $Title = $BranchName
    }
    
    $prArgs = @("pr", "create", "--base", $BaseBranch, "--head", $BranchName, "--title", $Title)
    if ($Body) {
        $prArgs += @("--body", $Body)
    } else {
        $prArgs += @("--fill")
    }
    if ($Draft) {
        $prArgs += "--draft"
    }

    try {
        $prUrl = & gh @prArgs
        Write-Host "==> Pull Request successfully created:" -ForegroundColor Green
        Write-Host $prUrl -ForegroundColor Yellow
        return $prUrl
    } catch {
        Write-Warning "Failed to create PR via gh: $_"
    }
} else {
    Write-Host "==> 'gh' CLI not found. Generating compare URL..." -ForegroundColor Yellow
    $remoteUrl = git config --get remote.origin.url
    # Transform SSH or HTTPS url into web URL
    if ($remoteUrl -match "github\.com[:/](.+?)/(.+?)(\.git)?$") {
        $owner = $Matches[1]
        $repo = $Matches[2]
        $compareUrl = "https://github.com/$owner/$repo/compare/$BaseBranch...$BranchName?expand=1"
        Write-Host "Open this URL in your browser to submit the PR:" -ForegroundColor Cyan
        Write-Host $compareUrl -ForegroundColor Yellow
    }
}
