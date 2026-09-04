# mattpocock-override

A Claude Code marketplace of **extensions to [Matt Pocock's skills](https://github.com/mattpocock/skills)**.

Upstream ships an excellent set of engineering skills as a read-only, managed plugin. That is the point of it, and also its limit: you cannot change a skill without forking the whole bundle, and a fork stops receiving updates the day you make it.

This repo takes the other route. Nothing from upstream is copied, and nothing wraps it. Each skill here extends an upstream skill **through the per-repo configuration upstream already reads** (`docs/agents/*.md`): a setup skill writes a standing rule there once, and the ordinary upstream skill follows it from then on. Upstream's updates keep arriving; this repo stays a few hundred lines of delta.

**Requires the upstream plugin.** These skills have nothing to do without it:

```bash
/plugin install mattpocock-skills
```

## What's here

| Skill                | Extends                    | Adds                                                                                                  |
| -------------------- | -------------------------- | ----------------------------------------------------------------------------------------------------- |
| `setup-triage-board` | `mattpocock-skills:triage` | A **GitHub Projects (v2) board** for triage: created once, named after the repo, recorded in `docs/agents/`. |
| `sync-triage-board`  | `mattpocock-skills:triage` | Moves an item's card when its triage label changes; audits drift and backfills the backlog on approval.  |

### Triage on a board

Upstream `/triage` moves issues through a state machine of labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. That works, but the only way to see the queue is a label query.

These two skills project that state machine onto a board without touching it:

- **Setup, once.** `/mattpocock-skills-override:setup-triage-board` checks the repo tracks issues on GitHub, creates the board (`<repo> Triage`, six columns on the built-in `Status` field, board layout, linked to the repo), writes its identity and column mapping to `docs/agents/github-project.md`, and adds one rule to `docs/agents/issue-tracker.md`: *every state label change is also a board move; call `sync-triage-board`.*
- **Triage, as before.** `/mattpocock-skills:triage`, the real one. It reads that rule like any other tracker convention. Each label it applies lands the item in the mapped column; each issue it creates is born on the board.
- **Labels stay the source of truth.** The board is derived. A card dragged by hand shows up as drift on the next triage, is reported, and is reconciled only after you say so.
- **The backlog is not swept in silently.** Issues triaged before the board existed surface as drift; `sync-triage-board` files them in one approved pass, in slices if you want.
- **Board failures never roll back label work.** A missing OAuth scope degrades to plain upstream triage instead of breaking it.
- **GitHub-only, by construction.** A repo set up for GitLab, local markdown, or another tracker gets no board and no offer of one.

Board writes need the `project` OAuth scope, which `gh auth login` does not request:

```bash
gh auth refresh -s project --hostname github.com
```

## Why not a wrapper

Upstream marks `triage` (and 21 other skills) `disable-model-invocation: true`, and its own convention says a user-invoked skill can never be reached by another skill, including through the Skill tool. So nothing can sit in front of `/triage`. What it *can* do is read configuration, and that is the seam these skills use. An earlier version of this repo was a wrapper; it could not run.

## Install

```bash
/plugin marketplace add doveaia/mattpocock-override
/plugin install mattpocock-skills-override@mattpocock-override
```

Then, in a repo that has already run `/setup-matt-pocock-skills`:

```
/mattpocock-skills-override:setup-triage-board
```

Skills here never reuse an upstream name, so there is nothing to disambiguate; invoke them by their qualified name.

## Adding a skill

1. `skills/<name>/SKILL.md`, flat (no category directory: Agent Plugins clients do not recurse), with a name that is not an upstream name.
2. Extend through `docs/agents/`, never by copying or wrapping. A setup skill writes the rule; a model-invoked helper does the work; the rule tells upstream to call the helper.
3. Runtime assets live in the skill's own folder.
4. Register the path in `.claude-plugin/plugin.json`, bump the version in both manifests, add a row above.

Keep the delta small and legible. The value here is the layer, not a rewrite.

## Layout

```
.claude-plugin/
  marketplace.json          marketplace "mattpocock-override"
  plugin.json               plugin "mattpocock-skills-override"
plugin.json                 the same plugin, Agent Plugins format
skills/
  setup-triage-board/
    SKILL.md                explore, confirm, create, write the config
    github-project.md       the rules written into the target repo
    create-triage-board.sh  build the board via GraphQL
  sync-triage-board/
    SKILL.md                move a card on a label change; drift and backfill
```

## Agent Plugins (agent-plugins.org) compatibility

The repo carries a second, portable manifest so the plugin also loads in clients that implement [Agent Plugins v1.0.0](https://agent-plugins.org/specification):

- **`plugin.json` at the repo root** is the portable manifest. `.claude-plugin/plugin.json` stays authoritative for Claude Code; neither client reads the other's file.
- **A flat `skills/` layout**, because Agent Plugins discovers only immediate children of `skills/` and never recurses.
- **No `mcp.json`.** That file is only for MCP servers, and this plugin ships none.

The two manifests duplicate name, version, description, author, repository, and license. **Change one, change the other.** Agent Plugins v1 has no field for depending on another plugin, so the dependency on `mattpocock-skills` is stated in the description only.

## Credit

The skills, and the state machine this builds on, are Matt Pocock's: [mattpocock/skills](https://github.com/mattpocock/skills). MIT on both sides.

## License

MIT. See [LICENSE](./LICENSE).
