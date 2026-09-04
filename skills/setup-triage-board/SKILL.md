---
name: setup-triage-board
description: "Give this repo's triage a GitHub Projects board: create it, record it, and wire the triage skills to keep it in step with the labels. Run once, after /setup-matt-pocock-skills."
disable-model-invocation: true
---

# Setup Triage Board

Give this repo's issue triage a board, once. Afterwards the ordinary `mattpocock-skills:triage` keeps it current: every triage state label it applies also moves the item's card.

That works because upstream's skills read their per-repo configuration from `docs/agents/`. This skill writes into that configuration: it creates the board, records its identity and column mapping in `docs/agents/github-project.md`, and adds the standing rule "every state label change is also a board move" to `docs/agents/issue-tracker.md`, which `triage` already reads for its tracker conventions. The move itself is done by `mattpocock-skills-override:sync-triage-board`, a model-invoked skill the rule tells `triage` to call.

Nothing here wraps or re-implements upstream. Upstream's `triage` is user-invoked, so no skill can call it; extending it through its own config is the supported path.

This is a prompt-driven skill, not a script. Explore, present what you found, confirm, then write.

## Process

### 1. Explore

Read what exists; don't assume:

- `docs/agents/issue-tracker.md`. Its first heading names the tracker (`# Issue tracker: GitHub`). **Missing** means `/setup-matt-pocock-skills` has never run: stop and tell the user to run it first. **Anything but GitHub** (GitLab, local markdown, freeform) means this skill has nothing to do: a GitHub Projects board only makes sense for issues that live in GitHub Issues. Say so in one line and stop. That is a normal outcome, not an error; never offer to create a GitHub project "anyway".
- `docs/agents/github-project.md`. Present means a board is already configured: this is a re-run. Ask whether to re-resolve the IDs against the existing board (the usual reason: a column was recreated) or stop.
- `gh auth status`: is the `project` OAuth scope present? Board writes need it.
- `gh repo view --json name,owner`: the repo and its owner.
- `gh project list --owner <owner> --format json --jq '.projects[] | {number, title, url}'`: boards that already exist under that owner. A project hangs off a user or org, not a repo, so a repo under an org normally wants the org's project.
- `CLAUDE.md` and `AGENTS.md` at the repo root: which one carries the `## Agent skills` block that `/setup-matt-pocock-skills` wrote.

### 2. Present and ask

Lead with the recommended answer so the user can accept it in a word.

**Scope.** If `project` is absent, stop here: `gh auth refresh -s project --hostname github.com`. Nothing below works without it.

**Which board.** If step 1 found existing projects, offer to reuse one; otherwise propose creating `<repo> Triage`. An owner-wide name like "Engineering Triage" collides across every repo of an org, so the default is qualified by the repo. Confirm the owner too.

**Columns, when reusing.** Resolve the existing Status options:

```bash
gh project field-list <number> --owner <owner> --format json \
  --jq '.fields[] | select(.name == "Status") | {id, options: (.options | map({id, name}))}'
```

Every one of the five state roles (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`) needs a column, and two roles may share one. Match by name where the names line up; otherwise show the columns and ask for the mapping. Do **not** run the creation script against a board that already has cards: it replaces the Status options wholesale.

### 3. Write

Show the user a draft of each file before writing it, and let them edit.

**Creating a board.** Run the script that ships next to this skill, in the repo being set up:

```bash
"$CLAUDE_PLUGIN_ROOT/skills/setup-triage-board/create-triage-board.sh" [--owner <login>] [--title "<title>"]
```

It names the project after the repo, defines the six triage columns on the built-in `Status` field, switches the default view to a board, links the project to the repo, and prints the complete `docs/agents/github-project.md`. Save that output verbatim. GitHub's Kanban template plays no part: it is reachable only from the web UI and none of its columns is a triage state, so the columns are defined directly.

**Reusing a board.** Compose `docs/agents/github-project.md` by hand: a `## Board` section (owner, number, title, project ID from `gh project view --format json --jq .id`, URL, Status field ID) and a `## Status options` table mapping each role to its column and option ID, followed by the contents of [github-project.md](github-project.md) from this skill's folder, unchanged.

**`docs/agents/issue-tracker.md`.** Append this section, or update it in place if one exists:

```markdown
## Project board

Triaged issues and PRs are mirrored to the GitHub Projects board **<title>** (<url>). Applying, removing, or changing a triage state label is also a board move: after the label change, call the Skill tool with `mattpocock-skills-override:sync-triage-board`. Labels are the source of truth; the board is derived from them. Board identity, column mapping, and the full rules: `docs/agents/github-project.md`.
```

**The `## Agent skills` block.** In whichever of `CLAUDE.md` / `AGENTS.md` already holds it, add this sub-block after `### Issue tracker`, or update it in place. Never create the other file; never touch the surrounding sections.

```markdown
### Triage board

Triaged issues are mirrored to the GitHub Projects board **<title>**; every state label change is also a Status move. See `docs/agents/github-project.md`.
```

### 4. Done

Tell the user:

- The board exists and is linked; give the URL.
- Triage is unchanged to invoke: `/mattpocock-skills:triage`. It now files each item it touches.
- Issues triaged before the board existed are not on it yet. They are backfill, and backfill is never done here or unprompted: the first `/mattpocock-skills:triage` will surface them as drift, and `sync-triage-board` files them once approved.

Re-run this skill only to re-resolve IDs after a column was recreated, or to point the repo at a different board.
