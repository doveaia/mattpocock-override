# The Triage Board (GitHub Projects v2)

Triage keeps a GitHub Projects (v2) board as a visual projection of the triage state machine. One card per triaged issue or PR; one Status column per state role.

Labels are the source of truth. The board is derived. When the two disagree, ask the maintainer rather than picking a winner.

## Prerequisites

Board writes go through the GraphQL Projects API, which needs the **`project`** OAuth scope. `gh auth login` does not request it.

```bash
gh auth status                                   # look for 'project' in Token scopes
gh auth refresh -s project --hostname github.com # grant it (read + write)
```

`read:project` is enough to read the board but not to move a card. If the scope is missing, do the label work, skip the board, and tell the maintainer the exact command above.

## Config file: `docs/agents/github-project.md`

Every ID below is resolved once, by a `gh` call, and written down. Never guess one.

```markdown
# Triage project board

- **Owner**: `acme-org` _(user or org login; the project's owner, not necessarily the repo's)_
- **Project number**: `3`
- **Project title**: `Engineering Triage`
- **Project ID**: `PVT_kwHOA...`
- **Project URL**: https://github.com/orgs/acme-org/projects/3
- **Status field ID**: `PVTSSF_lADOA...`

## Status options

| Triage state role | Column          | Option ID  |
| ----------------- | --------------- | ---------- |
| _(untriaged)_     | Inbox           | `f75ad846` |
| `needs-triage`    | Triage          | `47fc9ee4` |
| `needs-info`      | Needs Info      | `98236657` |
| `ready-for-agent` | Ready for Agent | `a1b2c3d4` |
| `ready-for-human` | Ready for Human | `e5f6a7b8` |
| `wontfix`         | Closed          | `c9d0e1f2` |

## Other fields maintained by triage

_(none by default; add rows as `Field name | Field ID | how triage sets it`)_
```

## First run

Run this when `docs/agents/github-project.md` is missing. It is a conversation, not a script: confirm before creating anything.

1. **Check the scope.** `gh auth status`. If `project` is absent, stop and ask for `gh auth refresh -s project --hostname github.com`.

2. **Find the owner.** `gh repo view --json owner,name,nameWithOwner`. Projects hang off a user or org, not a repo, so a repo under an org usually wants the org's project. Propose the owner, let the maintainer correct it.

3. **List existing projects** and ask whether to reuse one:

   ```bash
   gh project list --owner <owner> --format json --jq '.projects[] | {number, title, url}'
   ```

4. **Get a project. Prefer reuse, and prefer the web UI for creation.**

   `gh project create` takes only `--owner` and `--title`. It cannot pick a GitHub project template, cannot choose a view layout, and cannot rename a single-select option afterwards. What it produces is a **Table** view with a `Status` field of `Todo` / `In Progress` / `Done`: three columns, not a kanban, and not the five triage states.

   So when the maintainer wants an actual board, say this and let them do it once:

   > Create it at `https://github.com/orgs/<owner>/projects/new` (or `/users/<owner>/projects/new` for a personal one), from the **Kanban** or **Bug tracker** template, and rename the columns to the triage states you want. Tell me the project number when it exists.

   Step 3 then picks it up as an existing project and the rest of the setup is unchanged. This is the recommended path: one minute in the UI buys the right layout and the right columns.

   Only if the maintainer would rather not leave the terminal:

   ```bash
   gh project create --owner <owner> --title "<title>" --format json
   ```

   Then tell them plainly what they got: a table with `Todo` / `In Progress` / `Done`, needing one click in the UI to switch the view to Board, and column edits before the mapping in step 6 is anything but a squeeze of five states into three.

   **Default title: `<repo> Triage`** (e.g. `mattpocock-override Triage`), from `gh repo view --json name`. A project belongs to the owner, not the repo, so an unqualified name like "Engineering Triage" collides with every other repo under the same owner. Confirm the title before creating.

5. **Resolve the IDs:**

   ```bash
   gh project view <number> --owner <owner> --format json --jq '{id, title, url}'
   gh project field-list <number> --owner <owner> --format json \
     --jq '.fields[] | {id, name, type, options: (.options // [] | map({id, name}))}'
   ```

6. **Map state roles to columns.** Match by name where the columns line up; otherwise show the maintainer the columns that exist and ask for the mapping. Every one of the five state roles needs a column, and it is fine for two roles to share one.

7. **Write `docs/agents/github-project.md`** from the template above, show it to the maintainer, and only then start triaging.

## Status mapping

Applying a state role means applying the label *and* setting Status to the mapped column. The mapping lives in the config file; the defaults are:

| State role        | Column          |
| ----------------- | --------------- |
| `needs-triage`    | Triage          |
| `needs-info`      | Needs Info      |
| `ready-for-agent` | Ready for Agent |
| `ready-for-human` | Ready for Human |
| `wontfix`         | Closed          |

Category roles (`bug` / `enhancement`) stay labels. Don't model them as columns; a card has one Status and two categories would fight over it.

## Recipes

Substitute the values from `docs/agents/github-project.md`. `--format json` plus `--jq` keeps the output small.

**Add an issue or PR to the board** (idempotent: re-adding returns the existing card):

```bash
gh project item-add <number> --owner <owner> --url https://github.com/<owner>/<repo>/issues/42 \
  --format json --jq '.id'
```

**Find the card for a known issue number:**

```bash
gh project item-list <number> --owner <owner> --limit 500 --format json \
  --jq '.items[] | select(.content.number == 42) | {id, status, title: .content.title}'
```

**Set the Status column:**

```bash
gh project item-edit --id <ITEM_ID> --project-id <PROJECT_ID> \
  --field-id <STATUS_FIELD_ID> --single-select-option-id <OPTION_ID>
```

`--id` is the *item* ID (`PVTI_...`), not the issue number and not the issue's node ID. `--project-id` is required alongside `--field-id`.

**Read the board, grouped by column:**

```bash
gh project item-list <number> --owner <owner> --limit 500 --format json \
  --jq '.items | group_by(.status) | map({status: .[0].status, items: map({n: .content.number, t: .content.title})})'
```

**Create an issue straight onto the board** (by project *title*, not number):

```bash
gh issue create --title "..." --body "..." --label "bug,needs-triage" --project "Engineering Triage"
```

**Clear a field:** `gh project item-edit --id <ITEM_ID> --project-id <PROJECT_ID> --field-id <FIELD_ID> --clear`

## Drift

Drift is a card whose Status doesn't match its labels, or a triaged item with no card. Both are normal: people move cards by hand, and issues get labelled outside triage.

Report drift, don't silently fix it. List the items, say which side you'd trust for each and why, and let the maintainer approve the reconciliation in one pass. When they approve, labels win by default: set the board Status from the labels.

## Backfill

Issues triaged before the board existed carry labels but have no card. They are drift, and this is how you compute and clear them. Nothing here runs unprompted: present the list, get approval, then file in one pass.

**1. Every issue carrying a triage state label.** `--label` repeated is an AND in `gh issue list`, so use `--search`, where a comma-separated `label:` is an OR:

```bash
gh issue list --state all --limit 1000 \
  --search 'label:needs-triage,needs-info,ready-for-agent,ready-for-human,wontfix' \
  --json number,title,state,labels \
  --jq '.[] | {n: .number, title, state, labels: [.labels[].name]}'
```

**2. Everything already on the board:**

```bash
gh project item-list <number> --owner <owner> --limit 500 --format json \
  --jq '[.items[].content.number // empty] | sort | .[]'
```

`// empty` drops draft cards, which have no issue behind them.

**3. The difference is the backfill set.** Write both number lists to files and:

```bash
comm -23 <(sort triaged.txt) <(sort on-board.txt)
```

**4. Present it before filing.** Group by the state label each issue carries, so the maintainer sees which column each one is heading to, and say how many. A long backlog is worth filing in slices ("just the open ones", "skip wontfix") rather than all at once.

**5. File the approved set**, one item at a time: add the card, then set its Status from its state label (§ Recipes, § Status mapping). If one item fails, report it and keep going; don't abandon the batch. Report the count filed and the ones that failed.

Issues with **no** triage label at all are not backfill. They have never been triaged, so they belong in upstream's "Unlabeled" bucket and go onto the board the normal way, when triage reaches them.

## Failure modes

- **Missing `project` scope**: board calls fail with an HTTP 403 or a "missing required scopes" message. Never let this block label work.
- **Wrong owner**: `gh project list` returns an empty set for the *repo's* owner when the board actually belongs to a user, or vice versa. Re-check step 2.
- **Stale IDs**: deleting and recreating a column changes its option ID, and every board write then fails. Re-run field discovery (step 5) and rewrite the config file.
- **Classic projects**: `gh project` only speaks Projects v2. A pre-2022 classic project has to be migrated first; say so rather than working around it.
