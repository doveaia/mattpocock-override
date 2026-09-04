# CLAUDE.md

Operating rules for this repo. Read before adding or editing a skill.

## What this repo is

A Claude Code marketplace (`mattpocock-override`) publishing one plugin (`mattpocock-skills-override`).

Every skill here **extends an upstream skill from [mattpocock/skills](https://github.com/mattpocock/skills)** without copying it and without wrapping it. It works through the extension point upstream provides: the per-repo configuration in `docs/agents/`, which upstream's skills read at the start of their work. This repo holds the delta and nothing else, so upstream's updates keep arriving.

## The constraint that shapes everything

Upstream splits its skills into **user-invoked** (`disable-model-invocation: true`; 22 of 37, including `triage`, `to-spec`, `to-tickets`, `implement`, `wayfinder`) and **model-invoked**. Its own rule, in `.agents/invocation.md`: *a user-invoked skill can never be reached by another skill, including by naming it to the Skill tool.*

So a user-invoked upstream skill **cannot be wrapped**. An earlier version of this repo tried: a `triage` skill that delegated to `mattpocock-skills:triage` via the Skill tool. It could not run. Do not try again.

What works instead has two halves:

1. **A setup skill** (user-invoked, run once per repo). It creates whatever the extension needs and writes standing rules into `docs/agents/*.md`, the files upstream's skills already read. Upstream's `triage` then follows those rules the way it follows any tracker convention, and the human keeps invoking the real `mattpocock-skills:triage`.
2. **A helper skill** (model-invoked, no `disable-model-invocation`). It does the mechanical work. The rule written by the setup skill tells upstream to *call the Skill tool with it*, which is upstream's own convention for depending on a model-invoked skill, and is allowed.

Rules live in the target repo; recipes live in the plugin. A rule is short and rarely changes; a recipe changes with `gh`, and updating the plugin should update it everywhere.

## The rule that matters

**Never vendor upstream content.** No copied `SKILL.md`, no copied reference file, no restated state machine, role list, or template that upstream owns. The moment you copy something, it is frozen and the repo has silently become a fork. Name upstream's concepts and let upstream supply them; link to GitHub for its text.

To *consult* upstream, clone it to the scratchpad and read it there. Do not clone it into this repo, do not add it as a git remote, and do not copy files out of it.

## Naming

**Never reuse an upstream skill name.** This repo does not shadow upstream; it sits beside it. A same-named skill is at best ambiguous to invoke and at worst a loop. Name skills for what they add (`setup-triage-board`, `sync-triage-board`), and invoke them by qualified name, `mattpocock-skills-override:<name>`.

## Layering rules

- **Check the layer applies before acting.** Upstream's skills are configurable per repo, and a layer built on one choice must confirm it. The board skills read `docs/agents/issue-tracker.md` and stand down entirely unless the tracker is GitHub. Standing down is a normal outcome and needs no approval; never offer to do it "anyway".
- **Never roll back upstream's work.** If the layer's step fails, report which step, leave what upstream did in place, offer a retry. The layer is additive; a failure in it degrades the skill to plain upstream behaviour.
- **Name a source of truth.** When the layer introduces a second representation of the same state, one side is authoritative and the other derived. Report disagreement; never silently reconcile.
- **Nothing in bulk, unprompted.** Compute and present; write after approval.
- **Keep the delta legible.** A skill that runs long is usually re-explaining upstream. Cut it back to what is new.

## Layout

```
.claude-plugin/marketplace.json   marketplace "mattpocock-override"
.claude-plugin/plugin.json        plugin "mattpocock-skills-override" (Claude Code)
plugin.json                       the same plugin, Agent Plugins format
skills/<name>/                    one skill per folder, flat
```

**Skills live flat under `skills/`**, never under a category directory: Agent Plugins discovers `skills/<name>/SKILL.md` and is forbidden from recursing. The frontmatter `name` must equal the directory name.

**A skill's runtime assets live in its own folder**, next to its `SKILL.md`: scripts, templates, reference docs. There is no top-level `scripts/`. Reach for them with `$CLAUDE_PLUGIN_ROOT/skills/<name>/<file>`, never a path relative to the working directory, which at run time is the user's repo. Skills are only ever invoked as plugin skills, so that variable is always set; don't add a symlink installer or any second install path.

## The two manifests

`.claude-plugin/plugin.json` is authoritative for Claude Code. The root `plugin.json` targets [Agent Plugins v1.0.0](https://agent-plugins.org/specification) and is additive; neither client reads the other's file.

- **Keep them in sync.** Both carry name, version, description, author, repository, license, keywords. No generator: a change to one is a change to both.
- **The root manifest's schema is closed**: `$schema`, `name`, `version`, `description`, `author`, `homepage`, `repository`, `license`, `keywords`, `extensions` only. Claude Code fields go in `.claude-plugin/plugin.json`.
- **No `mcp.json` unless the plugin ships MCP servers.** It is not a copy of `.mcp.json`; it has its own schema.
- **Agent Plugins v1 has no dependency field.** The dependency on `mattpocock-skills` is stated in descriptions and enforced only by each skill's own pre-flight.

## Adding a skill

1. `skills/<name>/SKILL.md`, flat, with a name that is not an upstream name. User-invoked if a human starts it (a setup); model-invoked with a trigger-rich `description` if upstream is meant to call it.
2. Runtime assets in the same folder.
3. Register the path in `skills` in `.claude-plugin/plugin.json`, bump `version` in both manifests.
4. A row in the README table: skill, what it extends, what it adds.
5. Validate:

   ```bash
   claude plugin validate .
   claude plugin validate ./.claude-plugin/plugin.json
   ```

## Current skills

- **`setup-triage-board`** (user-invoked): creates a GitHub Projects v2 board for `triage`, named after the repo, six columns on the built-in Status field; writes `docs/agents/github-project.md` and the board rule into `docs/agents/issue-tracker.md` and the `## Agent skills` block. `create-triage-board.sh` does the deterministic part.
- **`sync-triage-board`** (model-invoked): moves an item's card when a triage label changes; computes and, on approval, reconciles drift and backfill. Labels are the source of truth.
