# project-config Specification

**File note:** `CLAUDE.md` is a symlink to this file (`AGENTS.md`). Always edit `AGENTS.md` directly.

## What This Repo Is

This is the canonical specification for `project-config.yaml`, a configuration format for software projects. The format standardizes how projects declare their git workflow, worktree management, task management, cross-project AI artifact availability, and terminal integration.

This is a **spec repo, not a code repo**. There is no runtime, no library, no CLI here. Contributions are spec changes, examples, schema updates, and documentation improvements.

## Repo Structure

```
spec/v1.md          # The specification (current version)
examples/           # Real-world project-config.yaml files
templates/          # Starter templates for common project types
schema/             # JSON Schema for validation
```

## Dogfooding

This repo uses its own `project-config.yaml` at the root. It serves as both a real configuration and a minimal example of the format.

## Quick Reference

The smallest valid `project-config.yaml` is two fields. A recommended starter config:

```yaml
schema_version: 1
repo: my-project
description: A short description of the project
canonical_branch: main
```

See `spec/v1.md` for the full specification, including optional fields for remote configuration, worktree management, task integration, cross-project AI skills, and terminal profiles.

## Task Management

This project uses [bloon](https://github.com/banagale/bloon) for task tracking (prefix: `pr-`).

- `bloon list` - show open tasks
- `bloon add "title"` - create a task
- `bloon done pr-<id>` - mark a task complete
- `bloon show pr-<id>` - view task details
- `/start` - session start with task suggestions
- `/bloon-resume pr-<id>` - switch to a specific task mid-session

## Working With This Repo

- Spec changes should be proposed as PRs with clear rationale
- Examples should reflect real usage patterns, not contrived demos
- Schema files should stay in sync with the spec
- Keep the spec precise but readable

## Conventions

- Plain English, no jargon where avoidable
- YAML for all configuration examples
- Semantic versioning for spec versions
- MIT license
