# CLAUDE.md

Operating rules for this repo. Read before adding or editing a skill.

## What this repo is

A Claude Code marketplace (`mattpocock-override`) publishing one plugin (`mattpocock-skills-override`).

Every skill here is a **wrapper around an upstream skill from [mattpocock/skills](https://github.com/mattpocock/skills)**. It keeps the upstream skill's name, delegates the actual work to it, and layers extra behaviour on top. This repo holds the delta and nothing else.

That is the whole architecture. It exists so upstream's updates keep arriving: a fork would stop receiving them the day it was made.

## The rule that matters

**Never vendor upstream content.** No copied `SKILL.md`, no copied reference file, no restated state machine, role list, or template that upstream owns.

The moment you copy something, it is frozen and the repo has silently become a fork. If a wrapper needs upstream's concepts, it names them and lets the upstream instructions supply them. If a reader needs upstream's text, link to it on GitHub.

To *consult* upstream, clone it to the scratchpad and read it there. Do not clone it into this repo, do not add it as a git remote, and do not copy files out of it.

## Anatomy of a wrapper skill

`skills/<upstream-name>/SKILL.md`, in three phases:

1. **Pre-flight.** What this layer needs before any upstream work runs: config files, credentials, scope checks. Fail loudly and early here, never mid-flow.
2. **Delegate.** Call the Skill tool on the upstream skill by its **fully qualified name**, `mattpocock-skills:<name>`.
3. **Layer rules.** The behaviour this repo adds, written as rules that stay in force over upstream's instructions for the rest of the session.

Phase 3 works because the Skill tool loads upstream's instructions into the *same* context. The wrapper's rules are already there and compose with them, rather than running once and disappearing. Write them as standing rules ("every state role change is also a board move"), not as a step that happens at a point in time.

### Qualified names, always

Phase 2 must use `mattpocock-skills:<name>`. A bare `<name>`, or this plugin's own `mattpocock-skills-override:<name>`, can resolve back to the wrapper itself and loop. Say so in the SKILL.md too, so the rule survives a future edit.

### Handle upstream being absent

The wrapper has nothing to run without the upstream plugin. Detect it, stop, and tell the user to run `/plugin install mattpocock-skills`. Never fall back to reimplementing upstream's flow.

## Layering rules well

- **State the precedence.** Where the layer and upstream touch, say which wins.
- **Check the layer even applies.** Upstream's skills are configurable per repo, and a layer built on one particular choice must confirm that choice before acting. `triage` reads `docs/agents/issue-tracker.md` and stands down entirely when the repo tracks issues anywhere but GitHub. Standing down is a normal outcome, not an error: the skill degrades to plain upstream behaviour and says so once.
- **Never roll back upstream's work.** If the layer's own step fails, report which step failed, leave what upstream did in place, and offer a retry. The layer is additive; a failure in it must degrade the skill to plain upstream behaviour, not break it.
- **Name a source of truth.** When the layer introduces a second representation of the same state, one side is authoritative and the other is derived. Report disagreement between them; never silently reconcile.
- **Keep the delta legible.** A wrapper that runs long is usually re-explaining upstream. Cut it back to what is genuinely new.

## Adding an override

1. Create `skills/<upstream-name>/SKILL.md` with the upstream `name:` in the frontmatter. A different name is not an override. **Flat, never under a category directory**: Agent Plugins discovers only immediate children of `skills/` and is forbidden from recursing, so a nested skill is invisible to conformant clients.
2. Reference files that are genuinely this repo's work live alongside it (e.g. `PROJECT-BOARD.md`). Upstream's do not.
3. Register the folder path in `skills` in `.claude-plugin/plugin.json`.
4. Add a row to the table in `README.md`: skill, what it wraps, what it adds.
5. Validate both manifests:

   ```bash
   claude plugin validate .
   claude plugin validate ./.claude-plugin/plugin.json
   ```

## Current overrides

- **`triage`** wraps `mattpocock-skills:triage`. Adds a GitHub Projects (v2) board as a projection of upstream's label state machine. Labels are the source of truth, the board is derived. Config and `gh` recipes: `skills/triage/PROJECT-BOARD.md`. Board creation is deterministic and lives in `skills/triage/create-triage-board.sh`, not in the skill prose.

## Layout

```
.claude-plugin/marketplace.json   marketplace "mattpocock-override"
.claude-plugin/plugin.json        plugin "mattpocock-skills-override"
plugin.json                       the same plugin, Agent Plugins format
skills/<name>/                    one wrapper per upstream skill, flat
```

A skill's runtime assets live **in its own folder**, next to its `SKILL.md`: reference docs, scripts, templates. There is no top-level `scripts/`. Upstream has one, but it holds repo tooling for the maintainer, which is a different thing from something a skill executes. A skill folder that is self-contained can be read, moved, or copied as the one unit it is, and the portable skill formats treat it that way too. Reach for it with `$CLAUDE_PLUGIN_ROOT/skills/<name>/<file>`.

Both plugins expose the same skill names, so a bare `/triage` is ambiguous. Skills here are invoked by their qualified name, `mattpocock-skills-override:<name>`. That is the only supported entry point: don't add a symlink installer to make the bare name resolve here, since a second install path means a second set of runtime assumptions to keep true.

## The second manifest (Agent Plugins)

The repo targets two formats. `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`
are authoritative for Claude Code. The root `plugin.json` targets
[Agent Plugins v1.0.0](https://agent-plugins.org/specification) and is purely additive —
neither client reads the other's file, and the root one must never replace them.

Rules when editing either:

- **Keep them in sync.** Both carry name, version, description, author, repository, license,
  keywords. There is no generator; a change to one is a change to both.
- **The root manifest schema is closed.** Only `$schema`, `name`, `version`, `description`,
  `author`, `homepage`, `repository`, `license`, `keywords`, `extensions` are legal top-level
  fields. Do not add Claude Code fields (`skills`, `commands`, `hooks`) to it — they belong in
  `.claude-plugin/plugin.json`, and anything client-specific belongs under `extensions` keyed
  by a reverse-domain namespace.
- **Skills live flat under `skills/`.** Agent Plugins discovers `skills/<name>/SKILL.md` and is
  forbidden from recursing, so a category directory would hide every skill under it from
  conformant clients. This is why the layout has no `<category>/` level, unlike upstream's.
  The frontmatter `name` must equal the directory name.
- **No `mcp.json` unless the plugin actually ships MCP servers.** It is not a copy of `.mcp.json`
  and has its own schema (`https://agent-plugins.org/schemas/1.0.0/mcp.schema.json`).
- **Agent Plugins v1 has no dependency field.** The dependency on `mattpocock-skills` lives in the
  root manifest's `description` and keywords, and is enforced by nothing but each wrapper's
  pre-flight check.
