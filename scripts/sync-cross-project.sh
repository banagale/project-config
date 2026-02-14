#!/usr/bin/env bash
# sync-cross-project.sh - Reference implementation for cross_project_availability
#
# Scans all projects with a project-config.yaml and creates/removes symlinks
# for shared AI skills and agents based on each project's configuration.
#
# Usage:
#   sync-cross-project.sh [OPTIONS]
#
# Options:
#   --dry-run     Show what would be done without making changes
#   --verbose     Show detailed output
#   --projects-dir DIR  Base directory to scan (default: ~/code/projects)
#   --help        Show this help message
#
# How it works:
#   1. Finds all project-config.yaml files under the projects directory
#   2. Reads cross_project_availability.skills and .agents from each
#   3. Based on the value ("all", "none", or a list), creates or removes
#      symlinks in ~/.claude/skills/ and ~/.claude/agents/
#   4. Cleans up stale symlinks that point to projects no longer sharing
#
# The script is idempotent: safe to run repeatedly. It only manages
# symlinks whose resolved targets fall within a scanned project root
# (a directory containing a project-config.yaml). Note: any symlink in
# ~/.claude/skills or ~/.claude/agents that resolves into a scanned
# project root is treated as managed and may be updated or removed.
#
# Only artifact directories containing SKILL.md (for skills) or
# AGENT.md (for agents) are discovered and linked.
#
# This is a reference implementation for the project-config.yaml spec.
# Adapt it to your environment as needed.

set -euo pipefail

# Require Bash 4+ (associative arrays)
if [[ -z "${BASH_VERSINFO:-}" || "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    echo "Error: Bash 4+ is required (associative arrays). On macOS, install via: brew install bash" >&2
    exit 1
fi

# Defaults
PROJECTS_DIR="${HOME}/code/projects"
DRY_RUN=false
VERBOSE=false

usage() {
    sed -n '2,/^$/s/^# //p' "$0"
    exit 0
}

log() { echo "$@"; }
verbose() { $VERBOSE && echo "  $@" || true; }
dry_run_prefix() { $DRY_RUN && echo "[dry-run] " || echo ""; }

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --verbose) VERBOSE=true; shift ;;
        --projects-dir) PROJECTS_DIR="$2"; shift 2 ;;
        --help) usage ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

PROJECTS_DIR="${PROJECTS_DIR/#\~/$HOME}"

# Check dependencies
if ! python3 -c "import yaml" 2>/dev/null; then
    echo "Error: PyYAML is required. Install it with: python3 -m pip install pyyaml"
    exit 1
fi
# Resolve a path to its real absolute path (works for broken symlinks too)
resolve_path() {
    if command -v realpath >/dev/null 2>&1; then
        realpath "$1" 2>/dev/null || python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$1"
    else
        python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$1"
    fi
}

PROJECTS_DIR_REAL="$(cd "$PROJECTS_DIR" 2>/dev/null && pwd -P)" || {
    echo "Error: projects directory does not exist: $PROJECTS_DIR"
    exit 1
}

# Target directories for symlinks
CLAUDE_SKILLS_DIR="${HOME}/.claude/skills"
CLAUDE_AGENTS_DIR="${HOME}/.claude/agents"

# Read a YAML field using Python (requires PyYAML)
yaml_get() {
    local file="$1" field="$2" default="${3:-}"
    local result
    result="$(python3 - "$file" "$field" "$default" <<'PY' 2>&1
import sys, yaml
file, field, default = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    with open(file, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}
except Exception as e:
    print(f"__YAML_ERROR__: {file}: {e}", file=sys.stderr)
    print(default)
    sys.exit(0)
val = data
for k in field.split("."):
    val = val.get(k) if isinstance(val, dict) else None
    if val is None:
        break
if val is None:
    print(default)
elif isinstance(val, list):
    print("\n".join(str(v) for v in val))
else:
    print(val)
PY
    )" || { echo "$default"; return; }
    if [[ "$result" == *"__YAML_ERROR__"* ]]; then
        log "  warn: ${result#*__YAML_ERROR__: }" >&2
        echo "$default"
    else
        echo "$result"
    fi
}

# Find the skills directory for a project
find_skills_dir() {
    local project_root="$1"
    # Check common locations
    for dir in "$project_root/skills" "$project_root/.claude/skills"; do
        if [[ -d "$dir" ]]; then
            echo "$dir"
            return 0
        fi
    done
    return 1
}

# Find the agents directory for a project
find_agents_dir() {
    local project_root="$1"
    for dir in "$project_root/agents" "$project_root/.claude/agents"; do
        if [[ -d "$dir" ]]; then
            echo "$dir"
            return 0
        fi
    done
    return 1
}

# List skill/agent names in a directory
# Skills must contain SKILL.md, agents must contain AGENT.md
list_artifacts() {
    local dir="$1"
    local type="$2" # "skills" or "agents"
    if [[ ! -d "$dir" ]]; then
        return
    fi
    local marker
    if [[ "$type" == "skills" ]]; then
        marker="SKILL.md"
    else
        marker="AGENT.md"
    fi
    for entry in "$dir"/*/; do
        [[ -d "$entry" ]] || continue
        local name
        name="$(basename "$entry")"
        [[ "$name" == .* ]] && continue
        # Require marker file to identify valid artifacts
        if [[ -f "$entry/$marker" ]]; then
            echo "$name"
        fi
    done
}

# Check if a resolved path belongs to a scanned project
target_is_scanned_project() {
    local target="$1"
    for project_root in "${!SCANNED_PROJECTS[@]}"; do
        if [[ "$target" == "$project_root/"* ]]; then
            return 0
        fi
    done
    return 1
}

# Create a managed symlink
create_symlink() {
    local source="$1"
    local target_dir="$2"
    local name="$3"
    local target="$target_dir/$name"

    if [[ -L "$target" ]]; then
        local existing
        existing="$(readlink "$target")"
        if [[ "$existing" == "$source" ]]; then
            verbose "  already linked: $name -> $source"
            return 0
        fi
        # Only update symlinks that point into a scanned project
        local resolved
        resolved="$(resolve_path "$target")"
        if target_is_scanned_project "$resolved"; then
            log "$(dry_run_prefix)update: $name -> $source (was $existing)"
            if ! $DRY_RUN; then
                rm "$target"
                ln -s "$source" "$target"
            fi
        else
            log "  skip: $name (existing symlink not managed by us)"
            return 0
        fi
    elif [[ -e "$target" ]]; then
        log "  skip: $name (non-symlink exists at target)"
        return 0
    else
        log "$(dry_run_prefix)link: $name -> $source"
        if ! $DRY_RUN; then
            mkdir -p "$target_dir"
            ln -s "$source" "$target"
        fi
    fi
}

# Remove a managed symlink
remove_symlink() {
    local target_dir="$1"
    local name="$2"
    local target="$target_dir/$name"

    if [[ -L "$target" ]]; then
        local existing resolved
        existing="$(readlink "$target")"
        resolved="$(resolve_path "$target")"
        # Only remove if it points into a scanned project
        if target_is_scanned_project "$resolved"; then
            log "$(dry_run_prefix)unlink: $name (was $existing)"
            if ! $DRY_RUN; then
                rm "$target"
            fi
        else
            verbose "  skip unlink: $name (not a project symlink)"
        fi
    fi
}

# Track which symlinks should exist (for stale cleanup)
declare -A EXPECTED_SKILLS
declare -A EXPECTED_AGENTS
# Track which project owns each name (for collision detection)
declare -A SKILL_OWNERS
declare -A AGENT_OWNERS
# Track which project roots we scanned (only clean up symlinks from these)
declare -A SCANNED_PROJECTS

log "Scanning projects in $PROJECTS_DIR..."
log ""

# Find all project-config.yaml files
configs_found=0
while IFS= read -r config_file; do
    project_root="$(dirname "$config_file")"
    project_root_real="$(resolve_path "$project_root")"
    project_name="$(basename "$project_root")"
    configs_found=$((configs_found + 1))
    SCANNED_PROJECTS["$project_root_real"]=1

    # Read cross_project_availability
    skills_policy="$(yaml_get "$config_file" "cross_project_availability.skills" "none")"
    agents_policy="$(yaml_get "$config_file" "cross_project_availability.agents" "none")"

    verbose "Project: $project_name"
    verbose "  skills: $skills_policy"
    verbose "  agents: $agents_policy"

    # Process skills
    if [[ "$skills_policy" != "none" ]]; then
        skills_dir="$(find_skills_dir "$project_root" 2>/dev/null || true)"
        if [[ -n "$skills_dir" ]]; then
            if [[ "$skills_policy" == "all" ]]; then
                while IFS= read -r skill_name; do
                    [[ -z "$skill_name" ]] && continue
                    if [[ -n "${SKILL_OWNERS[$skill_name]+x}" ]]; then
                        log "  warn: skill '$skill_name' from $project_name conflicts with ${SKILL_OWNERS[$skill_name]}, skipping"
                        continue
                    fi
                    create_symlink "$skills_dir/$skill_name" "$CLAUDE_SKILLS_DIR" "$skill_name"
                    EXPECTED_SKILLS["$skill_name"]=1
                    SKILL_OWNERS["$skill_name"]="$project_name"
                done < <(list_artifacts "$skills_dir" "skills")
            else
                # Specific list (one name per line from yaml_get)
                while IFS= read -r skill_name; do
                    [[ -z "$skill_name" ]] && continue
                    if [[ -n "${SKILL_OWNERS[$skill_name]+x}" ]]; then
                        log "  warn: skill '$skill_name' from $project_name conflicts with ${SKILL_OWNERS[$skill_name]}, skipping"
                        continue
                    fi
                    if [[ -d "$skills_dir/$skill_name" ]]; then
                        create_symlink "$skills_dir/$skill_name" "$CLAUDE_SKILLS_DIR" "$skill_name"
                        EXPECTED_SKILLS["$skill_name"]=1
                        SKILL_OWNERS["$skill_name"]="$project_name"
                    else
                        log "  warn: skill '$skill_name' not found in $skills_dir"
                    fi
                done <<< "$skills_policy"
            fi
        else
            verbose "  no skills directory found"
        fi
    fi

    # Process agents
    if [[ "$agents_policy" != "none" ]]; then
        agents_dir="$(find_agents_dir "$project_root" 2>/dev/null || true)"
        if [[ -n "$agents_dir" ]]; then
            if [[ "$agents_policy" == "all" ]]; then
                while IFS= read -r agent_name; do
                    [[ -z "$agent_name" ]] && continue
                    if [[ -n "${AGENT_OWNERS[$agent_name]+x}" ]]; then
                        log "  warn: agent '$agent_name' from $project_name conflicts with ${AGENT_OWNERS[$agent_name]}, skipping"
                        continue
                    fi
                    create_symlink "$agents_dir/$agent_name" "$CLAUDE_AGENTS_DIR" "$agent_name"
                    EXPECTED_AGENTS["$agent_name"]=1
                    AGENT_OWNERS["$agent_name"]="$project_name"
                done < <(list_artifacts "$agents_dir" "agents")
            else
                while IFS= read -r agent_name; do
                    [[ -z "$agent_name" ]] && continue
                    if [[ -n "${AGENT_OWNERS[$agent_name]+x}" ]]; then
                        log "  warn: agent '$agent_name' from $project_name conflicts with ${AGENT_OWNERS[$agent_name]}, skipping"
                        continue
                    fi
                    if [[ -d "$agents_dir/$agent_name" ]]; then
                        create_symlink "$agents_dir/$agent_name" "$CLAUDE_AGENTS_DIR" "$agent_name"
                        EXPECTED_AGENTS["$agent_name"]=1
                        AGENT_OWNERS["$agent_name"]="$project_name"
                    else
                        log "  warn: agent '$agent_name' not found in $agents_dir"
                    fi
                done <<< "$agents_policy"
            fi
        else
            verbose "  no agents directory found"
        fi
    fi

done < <(find "$PROJECTS_DIR" -maxdepth 2 -name "project-config.yaml" -type f 2>/dev/null | sort)

# Clean up stale symlinks in skills dir
# Only removes symlinks pointing to projects we scanned (have project-config.yaml).
# Symlinks from other sources (e.g., cli-ai-setup's own setup) are left alone.
if [[ -d "$CLAUDE_SKILLS_DIR" ]]; then
    verbose ""
    verbose "Checking for stale skill symlinks..."
    for entry in "$CLAUDE_SKILLS_DIR"/*; do
        [[ -L "$entry" ]] || continue
        name="$(basename "$entry")"
        resolved="$(resolve_path "$entry")"
        # Skip if it should exist
        [[ -n "${EXPECTED_SKILLS[$name]+x}" ]] && continue
        # Only remove if pointing to a project we scanned
        target_is_scanned_project "$resolved" || continue
        remove_symlink "$CLAUDE_SKILLS_DIR" "$name"
    done
fi

# Clean up stale symlinks in agents dir
if [[ -d "$CLAUDE_AGENTS_DIR" ]]; then
    verbose ""
    verbose "Checking for stale agent symlinks..."
    for entry in "$CLAUDE_AGENTS_DIR"/*; do
        [[ -L "$entry" ]] || continue
        name="$(basename "$entry")"
        resolved="$(resolve_path "$entry")"
        [[ -n "${EXPECTED_AGENTS[$name]+x}" ]] && continue
        target_is_scanned_project "$resolved" || continue
        remove_symlink "$CLAUDE_AGENTS_DIR" "$name"
    done
fi

log ""
log "Done. Scanned $configs_found projects."
$DRY_RUN && log "(dry-run mode - no changes made)"
