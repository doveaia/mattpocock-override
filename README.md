# mattpocock-override

A Claude Code marketplace holding **drop-in overrides for [Matt Pocock's skills](https://github.com/mattpocock/skills)**.

Upstream ships an excellent set of engineering skills as a read-only, managed plugin. That is the point of it, and also its limit: you cannot change a skill without forking the whole bundle. This repo takes the other route. It holds only the skills I actually wanted to change, each keeping its **upstream name** so it can stand in for the original, and leaves everything else to upstream.

## What's overridden

| Skill    | Change                                                                                                                     |
| -------- | -------------------------------------------------------------------------------------------------------------------------- |
| `triage` | Every issue triage touches is filed onto a **GitHub Projects (v2) board**, and each state role is mirrored to a Status column. |

### `triage`: issues on a board

Upstream `/triage` moves issues through a state machine of labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. That works, but the only way to see the queue is to run label queries.

This version keeps the state machine exactly as it is and projects it onto a board:

- **Nothing falls off.** Any issue or PR triage touches gets a card, and issues triage *creates* are born on the board (`gh issue create --project`).
- **Labels stay the source of truth.** The board is derived. When a card is dragged by hand and the labels disagree, triage reports the drift and asks, rather than picking a winner.
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

An override only helps if it is the one that runs. Pick one:

**Don't install upstream's `triage`.** Cleanest. Install the upstream plugin for everything else and invoke this one for triage.

**Or link it into the project.** Project-level skills in `.claude/skills/` take precedence over plugin skills of the same name:

```bash
git clone https://github.com/doveaia/mattpocock-override
./mattpocock-override/scripts/link-skills.sh /path/to/your/repo
```

Symlinks, so a `git pull` here updates every repo you linked.

If both are installed and neither is shadowed, disambiguate by namespace: `mattpocock-skills-override:triage`.

## Adding an override

1. `skills/<category>/<upstream-skill-name>/SKILL.md`. Keep the upstream `name:` in the frontmatter, or it isn't an override.
2. Copy any reference file the SKILL.md links to into the same folder, so the skill folder stands alone.
3. Add the path to `skills` in `.claude-plugin/plugin.json`.
4. Say what changed, and why, in the table above.

Keep the diff from upstream small and legible. The value here is the delta, not a rewrite.

## Layout

```
.claude-plugin/
  marketplace.json     marketplace "mattpocock-override"
  plugin.json          plugin "mattpocock-skills-override"
skills/
  engineering/triage/
    SKILL.md           the override
    PROJECT-BOARD.md   board config, gh recipes, Status mapping
    AGENT-BRIEF.md     verbatim from upstream
    OUT-OF-SCOPE.md    verbatim from upstream
scripts/
  link-skills.sh       symlink skills into a repo's .claude/skills/
```

## Credit

The skills, and the state machine this builds on, are Matt Pocock's: [mattpocock/skills](https://github.com/mattpocock/skills). `AGENT-BRIEF.md` and `OUT-OF-SCOPE.md` are carried over unchanged. MIT on both sides.

## License

MIT. See [LICENSE](./LICENSE).
