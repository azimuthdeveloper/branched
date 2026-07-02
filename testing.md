# Branched — Integration Testing Plan

This document outlines the test specifications and implementation details for testing every critical Git scenario in a real Git repository environment. These tests run in the integration test suite (`integration_test/real_git_flow_test.dart`) using the actual `git` CLI (via `RealGitService`) and a dynamically created local scratch repository.

---

## 📋 Git Scenarios & Test Specifications

### 1. Repository Lifecycle: Initialization & Opening
- **Scenario:** The user opens the application, initializes a new repository, or opens an existing repository.
- **Git commands executed:** `git init`, `git rev-parse --git-dir`
- **Verification:**
  - Verify that the Welcome Screen options function correctly.
  - Verify that opening a valid repository loads the Main Workspace.
  - Verify that opening an invalid directory displays an error message/state.

### 2. Branch Management
- **Scenario:** The user checks out, creates, renames, and deletes local and remote branches.
- **Git commands executed:** `git checkout`, `git branch`, `git branch -m`, `git branch -d`
- **Verification:**
  - Verify that all local and remote branches are listed in the Sidebar.
  - Verify that checking out a branch updates the HEAD indicator in the Sidebar and refreshes the Commit Graph.
  - Verify that creating a branch via a context menu correctly creates the branch at the selected commit.
  - Verify that deleting a branch prompts for confirmation and removes the branch.

### 3. File Staging & Committing
- **Scenario:** The user makes edits to the working directory, stages/unstages individual or all files, discards changes, and commits.
- **Git commands executed:** `git add`, `git reset`, `git checkout --`, `git clean -fd`, `git commit`
- **Verification:**
  - Verify that modified, added, and deleted files appear in the Unstaged Changes section with appropriate status badges ('M', 'A', 'D').
  - Verify that staging/unstaging a file moves it between lists.
  - Verify that entering a commit summary and description and pressing `Commit` (or `Cmd/Ctrl + Enter`) creates a new commit.
  - Verify that the staging area becomes empty and the Commit Graph updates to display the new commit.

### 4. Merging & Conflict Resolution
- **Scenario:** The user merges a branch into HEAD, which may result in a clean merge (fast-forward or merge commit) or conflicts.
- **Git commands executed:** `git merge`, `git merge --abort`, `git add`
- **Verification:**
  - **Fast-Forward Merge:** Verify that the branch pointer updates instantly on the Commit Graph.
  - **Merge Commit:** Verify that a new merge commit is painted on the Commit Graph with multiple parent connections.
  - **Conflicts:**
    - Verify that conflicted files appear with a conflict badge in the Unstaged changes list.
    - Verify that a file conflict is resolved by editing/replacing the files.
    - Verify that staging the resolved file clears the conflict status and allows committing the merge.

### 5. Rebase & Sync Operations
- **Scenario:** The user rebases HEAD onto another branch, handles rebase-in-progress, and fetches/pulls/pushes.
- **Git commands executed:** `git rebase`, `git rebase --continue`, `git rebase --abort`, `git fetch`, `git pull`, `git push`
- **Verification:**
  - Verify rebase onto a target branch updates the Commit Graph commits structure.
  - Verify sync indicators in the Sidebar (ahead/behind counts: `↑ahead ↓behind`).

### 6. Stash Management
- **Scenario:** The user pushes unstaged changes to the stash stack, views stashes, applies, pops, and drops stashes.
- **Git commands executed:** `git stash push`, `git stash list`, `git stash apply`, `git stash pop`, `git stash drop`
- **Verification:**
  - Verify that stashes appear in the Stashes section of the Sidebar with a badge showing the stash stack count.
  - Verify that popping a stash restores modified files to the unstaged changes list.
  - Verify that dropping a stash deletes it from the Sidebar.

### 7. Submodule Verification
- **Scenario:** The user views submodules, updates/initializes them, and navigates to submodules.
- **Git commands executed:** `git submodule status`, `git submodule init`, `git submodule update`, `git submodule sync`
- **Verification:**
  - Verify that submodules are automatically detected and rendered under the Submodules section in the Sidebar.
  - Verify that the status of each submodule is correctly parsed (Clean, Modified, Uninitialized).
  - Verify that opening a submodule opens it in a new repository tab.

---

## 🛠️ Test Setup & Repository Generation

The integration test creates a temporary local Git repository programmatically using a wrapper helper class `TestRepoBuilder`. The repository is initialized, configured with user details, and populated with files, branches, submodules, stashes, and tags locally—preventing any external network dependencies.

```
/root/branched/test_resources/real_git_test_repo
├── .git/
├── .gitmodules
├── Readme.md
├── lib/
│   └── main.dart
└── plugins/
    └── my_submodule (local submodule)
```

The test runner sets up the `RealGitService` pointing to this directory via a test-mocked `FilePickerService`. The UI is then driven via the `WidgetTester` driver to execute user actions (tapping buttons, entering text, right-clicking rows) and verifying the state of the widgets against the real filesystem changes.
