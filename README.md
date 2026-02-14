# project-config

**One file to describe how your project works.** A portable YAML format that replaces scattered tribal knowledge with a single source of truth for git workflow, task tracking, AI tool integration, and more.

```yaml
schema_version: 1
repo: my-project
description: My awesome project
canonical_branch: main
```

Drop a `project-config.yaml` in your project root. The smallest valid config is two fields (`schema_version` and `repo`). The recommended starter above adds `description` and `canonical_branch`. Add sections as you need them.

- **Git workflow** - branch conventions, remote config, worktree management
- **Task tracking** - integration with issue trackers and project management tools
- **AI artifacts** - declare which skills and agents are shared across projects
- **Terminal integration** - tab colors, visual cues, environment hints
- **Incremental adoption** - only declare what you use, sensible defaults for the rest

**[Read the full spec](spec/v1.md)** | [Examples](examples/) | [Templates](templates/)

---

## Why

Project configuration lives in dozens of tool-specific files, undocumented conventions, and README fragments. A new contributor, human or AI, has to reverse-engineer the git workflow, figure out which branch is canonical, discover how tasks are tracked, and guess at the project's structure.

`project-config.yaml` makes all of that explicit and machine-readable.

## Implementations

Tools that consume `project-config.yaml`:

| Project | Description | Status |
|---------|-------------|--------|
| bloon | Task and project management CLI | Reference implementation |
| cli-ai-setup | Development environment bootstrap toolkit | Reference implementation |

These implementations are currently internal. Build a tool that reads or writes `project-config.yaml`? Open an issue or PR to list yours.

## Contributing

This is a spec repo. Contributions typically fall into:

- **Spec changes** - Propose additions or clarifications via PR with rationale and a real use case
- **Examples** - Add your project's `project-config.yaml` to [`examples/`](examples/)
- **Schema updates** - Keep [`schema/`](schema/) in sync with spec changes
- **Templates** - Add starter templates to [`templates/`](templates/)

## License

MIT License. See [LICENSE](LICENSE) for details.
