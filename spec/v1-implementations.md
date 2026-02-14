# Implementation Map for project-config.yaml v1

**Status:** Non-normative reference
**Last updated:** 2026-02-14

This document maps spec fields to known implementations. It is maintained alongside the specification but is not part of the normative spec. Line numbers are approximate and may drift between commits.

---

## Core Identity

| Field | Implementation | Notes |
|---|---|---|
| `schema_version` | bloon `config.py` | Read, not validated |
| `schema_version` | cli-ai-setup `common.sh` | Read, not validated |
| `repo` | bloon `config.py` | Used as project identifier |
| `repo` | cli-ai-setup `common.sh` | Display |

## Git Workflow

| Field | Implementation | Notes |
|---|---|---|
| `canonical_branch` | bloon `config.py` | Auto-detected from git |
| `canonical_branch` | cli-ai-setup `wt-sync.sh` | Core sync logic |
| `canonical_branch` | a large monorepo consumer `sync-parent.sh`, `worktree-status.sh`, `worktree-init.sh` | Via `iterate_worktrees` |

## Sync Configuration

| Field | Implementation | Notes |
|---|---|---|
| `sync.strategy` | bloon `config.py` | Written to config |
| `sync.strategy` | cli-ai-setup `wt-sync.sh` | Applied during sync |
| `sync.push_to_canonical` | cli-ai-setup `wt-sync.sh` | Also accepts legacy alias `publish_to_canonical` |

## Hooks

| Field | Implementation | Notes |
|---|---|---|
| `hooks.post_init` | bloon `config.py` | String or array |
| `hooks.post_init` | cli-ai-setup `wt-init.sh` | Executed via `run_hook` |
| `hooks.pre_sync` / `post_sync` | cli-ai-setup `wt-sync.sh` | Per-worktree hooks via `common.sh:run_hook()` |
| `hooks.pre_sync_all` / `post_sync_all` | cli-ai-setup `wt-sync-all.sh` | Batch hooks |

Real-world example: the a large monorepo consumer project uses `hooks.post_sync: ./scripts/gitops/hooks/sync-nested-repo-hook.sh` to sync nested repos after parent sync.

## Task Management

| Field | Implementation | Notes |
|---|---|---|
| `task.type` | bloon `config.py` | Routes to task system; only "bloon" and "none" handled |

## Terminal Integration

| Field | Implementation | Notes |
|---|---|---|
| `color_palette` | cli-ai-setup `post-init-color.sh` | Assigns by worktree index |
| `color_palette` | cli-ai-setup `iterm-tab-worktree-setup.sh` | Tab color setup |
| `color_palette` | bloon `bloon-statusline.sh` | Reads `meta.color` for display |

## Worktrees

| Field | Implementation | Notes |
|---|---|---|
| `worktrees[].name` | bloon `config.py`, `bloon-statusline.sh` | Display and identification |
| `worktrees[].name` | cli-ai-setup all `wt-*.sh` scripts | Core worktree operations |
| `worktrees[].name` | a large monorepo consumer all 9 gitops scripts | Via `iterate_worktrees` |
| `worktrees[].nested_repos` | cli-ai-setup `wt-reset.sh` | Resets nested repos to landing branches |

### Known Gaps

- The a large monorepo consumer project defines `nested_repos` in config but its sync scripts (`sync-nested-repo.sh`, `install-deps.sh`, `sync-nested-repo-hook.sh`) previously hardcoded `repos/nested-repo` rather than reading from config. `sync-nested-repo.sh` was updated to read from config in Feb 2026.
- `worktrees[].archived` is respected by cli-ai-setup sync tools but not by bloon task displays.
