---
name: sync-triage-board
description: Move an issue or PR's card on the repo's GitHub Projects triage board to the column matching its triage state label. Use right after a triage state label (needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix) is applied, removed, replaced or changed on an issue or PR, after "move issue 42 to ready-for-agent", after an issue is created with one of those labels, when the user asks to put an issue "on the board", "in a column", "in the Inbox", or "under Ready for Human", or when they ask to check the board for drift, audit the board against labels, reconcile cards, or backfill the backlog onto the board. Reads docs/agents/github-project.md; stands down if it is absent.
---

# Sync triage board

Project the triage state labels of one item, or the whole tracker, onto the GitHub Projects (v2) board configured for this repo. Labels are the input; the board is the output.

## Rules

- **Labels are the source of truth. The board is derived.** Never add, remove or change a label from here. Never "fix" a label to match a card.
- **Labels first, board second.** This runs after the label is applied. A board failure never rolls anything back: say which step failed, leave the labels alone, offer a retry.
- **Only state labels map to columns.** `bug` / `enhancement` stay labels.
- **Two state labels on one item is a conflict.** Do not guess. Report both and stop; the triage skill owns the fix.
- **HTTP 403 or "missing required scopes"** means the `project` OAuth scope is absent. Tell the user to run `gh auth refresh -s project --hostname github.com`. Never let this block anything else.
- **Nothing is filed in bulk unprompted.** Drift and backfill are computed and presented. Writing waits for approval.
- **Never create a project.** That is `/mattpocock-skills-override:setup-triage-board`.

## Pre-flight

Read `docs/agents/github-project.md` in the working directory. If it is missing, say in one line that no triage board is configured for this repo and that `/mattpocock-skills-override:setup-triage-board` creates one. Then do nothing else. This is not an error.

From the file take: owner, project number, project ID, Status field ID, and the state role to column to option ID table. The `_(untriaged)_` row is the column for an item with no state label.

## Move one item

Inputs: the issue or PR number, and the state label now on it.

1. **Resolve the URL and labels.** `gh issue view <n> --json url,labels --jq '{url, labels: [.labels[].name]}'`. If that fails, try `gh pr view` (issues and PRs share one number space).
2. **Pick the option.** Exactly one state label: its row. No state label: the `_(untriaged)_` row. More than one: report the conflict and stop.
3. **Ensure a card.** `item-add` is idempotent and returns the existing card when there is one:

   ```bash
   gh project item-add <number> --owner <owner> --url <url> --format json --jq '.id'
   ```

4. **Set Status.**

   ```bash
   gh project item-edit --id <ITEM_ID> --project-id <PROJECT_ID> \
     --field-id <STATUS_FIELD_ID> --single-select-option-id <OPTION_ID>
   ```

   `--id` is the card ID (`PVTI_...`), not the issue number and not the issue node ID. `--project-id` is required alongside `--field-id`.

5. **Report in one line**: item, column it landed in, project URL.

When several items were labelled in the same pass, run these steps per item and report one line each.

## Audit for drift and backfill

On request only ("check the board", "backfill the backlog", "anything drifted?").

1. **Every issue carrying a state label.** Repeated `--label` is an AND in `gh issue list`; `--search` with a comma-separated `label:` is an OR:

   ```bash
   gh issue list --state all --limit 1000 \
     --search 'label:needs-triage,needs-info,ready-for-agent,ready-for-human,wontfix' \
     --json number,title,state,labels \
     --jq '.[] | {n: .number, title, state, labels: [.labels[].name]}'
   ```

2. **Everything on the board with its Status:**

   ```bash
   gh project item-list <number> --owner <owner> --limit 500 --format json \
     --jq '.items[] | select(.content.number) | {n: .content.number, status}'
   ```

3. **Compare.** Labelled and absent from the board: backfill. Present and Status not the mapped column: drift. Two state labels: conflict, listed separately, never written. Issues with no state label are not backfill; they have never been triaged.

4. **Present**, grouped by target column with a count per group and a total. Offer slices: "just the open ones", "skip wontfix", "drift only". Wait for approval.

5. **File the approved set** one item at a time with the "Move one item" steps. If one fails, report it and keep going. End with the count filed and the list that failed.

## Reading the board

Grouped by column, for a quick picture or to confirm a move:

```bash
gh project item-list <number> --owner <owner> --limit 500 --format json \
  --jq '.items | group_by(.status) | map({status: .[0].status, items: map(.content.number)})'
```

Card for a known number:

```bash
gh project item-list <number> --owner <owner> --limit 500 --format json \
  --jq '.items[] | select(.content.number == 42) | {id, status}'
```

## When a write fails

- **403 / missing required scopes**: `gh auth refresh -s project --hostname github.com`, then retry.
- **Option ID rejected**: a column was deleted and recreated in the UI, which changes its ID. Tell the user to re-run `/mattpocock-skills-override:setup-triage-board`.
- **Empty item list for the owner**: the board belongs to a user when the org was asked, or the reverse. Trust the owner in the config file, not the repo.
