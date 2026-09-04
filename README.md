# mattpocock-override

A Claude Code marketplace holding **thin overrides for [Matt Pocock's skills](https://github.com/mattpocock/skills)**.

Upstream ships an excellent set of engineering skills as a read-only, managed plugin. That is the point of it, and also its limit: you cannot change a skill without forking the whole bundle, and a fork stops receiving updates the day you make it.

This repo takes the other route. Each skill here is a **wrapper**, not a copy. It delegates the actual work to the upstream skill by its qualified name and layers its own rules on top. Nothing from upstream is vendored, so upstream's updates arrive normally and this repo stays a few hundred lines of delta.

**Requires the upstream plugin.** These skills have nothing to run without it:

```bash
/plugin install mattpocock-skills
```

## What's overridden

| Skill    | Wraps                     | Adds                                                                                              |
| -------- | ------------------------- | ------------------------------------------------------------------------------------------------- |
| `triage` | `mattpocock-skills:triage` | Files every triaged issue or PR onto a **GitHub Projects (v2) board**, mirroring state role to Status column. |

### `triage`: issues on a board

Upstream `/triage` moves issues through a state machine of labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. That works, but the only way to see the queue is to run label queries.

This wrapper leaves that state machine entirely alone and projects it onto a board:

- **Nothing falls off.** Any issue or PR triage touches gets a card, and issues triage *creates* are born on the board (`gh issue create --project`).
- **Labels stay the source of truth.** The board is derived. When a card is dragged by hand and the labels disagree, it reports the drift and asks, rather than picking a winner.
- **State role to column** is a mapping you own, written to `docs/agents/github-project.md` on first run alongside the resolved project, field, and option IDs. No ID is ever guessed.
- **Board failures never roll back label work.** A missing OAuth scope degrades the skill to plain upstream behaviour instead of breaking it.
- **GitHub-only, by construction.** `/setup-matt-pocock-skills` lets a repo track issues in GitLab, local markdown, or elsewhere. When it does, the board layer stands down and you get plain upstream triage: no GitHub project is created for a repo whose issues do not live in GitHub.

First run resolves everything: it reuses a project if you have one, or runs `scripts/create-triage-board.sh` to build the board, named after the repo. `gh project create` yields a Table view with `Todo` / `In Progress` / `Done`, so the script takes it the rest of the way through GraphQL: the six triage columns on the built-in `Status` field, a `BOARD_LAYOUT` default view, and the project linked to the repo. It then prints `docs/agents/github-project.md` with every ID resolved.

GitHub's Kanban template is not involved: it exists only in the web UI's creation form, and none of its three columns is a triage state, so the columns are defined directly.

Board writes need the `project` OAuth scope, which `gh auth login` does not request:

```bash
gh auth refresh -s project --hostname github.com
```

## Install

```bash
/plugin marketplace add doveaia/mattpocock-override
/plugin install mattpocock-skills-override@mattpocock-override
```

### Invoking it

Always by its qualified name:

```
mattpocock-skills-override:triage
```

The upstream plugin stays installed, since the wrapper calls into it, so both plugins expose a skill named `triage` and a bare `/triage` is ambiguous by construction. The namespace is the answer, and it needs no per-repo setup.

## Adding an override

1. `skills/<upstream-skill-name>/SKILL.md`, flat: no category directory, because Agent Plugins clients do not recurse into one. Keep the upstream `name:` in the frontmatter, or it isn't an override.
2. Structure it in three phases: pre-flight, delegate to `mattpocock-skills:<skill>` by qualified name, then the rules your layer adds. Always use the qualified name; a bare one can resolve back to your own skill and loop.
3. Don't copy upstream files. If you need to point at one, link to it on GitHub.
4. Add the path to `skills` in `.claude-plugin/plugin.json`, and a row to the table above.

Keep the delta small and legible. The value here is the layer, not a rewrite.

## Layout

```
.claude-plugin/
  marketplace.json        marketplace "mattpocock-override"
  plugin.json             plugin "mattpocock-skills-override"
plugin.json               the same plugin, Agent Plugins format
skills/
  triage/
    SKILL.md              the wrapper: pre-flight, delegate, board rules
    PROJECT-BOARD.md      board config, gh recipes, Status mapping
scripts/
  create-triage-board.sh  build the triage board via GraphQL
```

## Agent Plugins (agent-plugins.org) compatibility

The repo carries a **second, portable manifest** so the plugin also loads in clients
that implement [Agent Plugins v1.0.0](https://agent-plugins.org/specification):

- **`plugin.json` at the repo root** — the portable manifest. `.claude-plugin/plugin.json`
  stays the authoritative one for Claude Code; the root file is additive and neither
  client reads the other's.
- **A flat `skills/` layout.** Agent Plugins discovers skills only in *immediate* children of
  `skills/` and never recurses, so a skill under a category directory is invisible to a
  conformant client. Hence `skills/triage/`, not `skills/engineering/triage/`. Upstream's
  category layout works there because Claude Code lists skill paths explicitly; here the
  portable format sets the shape.
- **No `mcp.json`.** That file is only for MCP servers, and this plugin ships none.

The two manifests duplicate name, version, description, author, repository, and license.
**Change one, change the other.**

Agent Plugins v1 has no field for depending on another plugin, so the hard dependency on
`mattpocock-skills` is stated in the root manifest's `description` and keywords only.
Nothing enforces it.

## Credit

The skills, and the state machine this builds on, are Matt Pocock's: [mattpocock/skills](https://github.com/mattpocock/skills). MIT on both sides.

## License

MIT. See [LICENSE](./LICENSE).
