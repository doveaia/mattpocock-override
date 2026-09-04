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

First run resolves everything interactively: it finds or creates the project, discovers the Status field's options, proposes a mapping, and writes the config once.

Board writes need the `project` OAuth scope, which `gh auth login` does not request:

```bash
gh auth refresh -s project --hostname github.com
```

## Install

```bash
/plugin marketplace add doveaia/mattpocock-override
/plugin install mattpocock-skills-override@mattpocock-override
```

### Making the override actually win

Both plugins expose a skill called `triage`, so a bare `/triage` is ambiguous. Pick one:

**Call it by namespace.** `mattpocock-skills-override:triage` is always unambiguous, and needs no setup.

**Or link it into the project.** Project-level skills in `.claude/skills/` take precedence over plugin skills of the same name, which makes bare `/triage` resolve here:

```bash
git clone git@github.com:doveaia/mattpocock-override.git
./mattpocock-override/scripts/link-skills.sh /path/to/your/repo
```

Symlinks, so a `git pull` here updates every repo you linked.

Either way the upstream plugin stays installed: the wrapper calls into it.

## Adding an override

1. `skills/<category>/<upstream-skill-name>/SKILL.md`. Keep the upstream `name:` in the frontmatter, or it isn't an override.
2. Structure it in three phases: pre-flight, delegate to `mattpocock-skills:<skill>` by qualified name, then the rules your layer adds. Always use the qualified name; a bare one can resolve back to your own skill and loop.
3. Don't copy upstream files. If you need to point at one, link to it on GitHub.
4. Add the path to `skills` in `.claude-plugin/plugin.json`, and a row to the table above.

Keep the delta small and legible. The value here is the layer, not a rewrite.

## Layout

```
.claude-plugin/
  marketplace.json     marketplace "mattpocock-override"
  plugin.json          plugin "mattpocock-skills-override"
skills/
  engineering/triage/
    SKILL.md           the wrapper: pre-flight, delegate, board rules
    PROJECT-BOARD.md   board config, gh recipes, Status mapping
scripts/
  link-skills.sh       symlink skills into a repo's .claude/skills/
```

## Credit

The skills, and the state machine this builds on, are Matt Pocock's: [mattpocock/skills](https://github.com/mattpocock/skills). MIT on both sides.

## License

MIT. See [LICENSE](./LICENSE).
