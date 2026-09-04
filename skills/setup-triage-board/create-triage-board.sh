#!/usr/bin/env bash
# Create the /triage board: a GitHub Projects (v2) board with one column per
# triage state.
#
# GitHub's Kanban template is not involved. It only exists in the web UI's
# creation form, and it would be the wrong starting point anyway: its columns
# are Todo / In Progress / Done, none of which is a triage state, so every one
# of them would have to be replaced. We define the columns directly instead.
#
#   1. create the project, named after the git repo
#   2. define the triage columns on the Status field
#   3. switch the default view to BOARD_LAYOUT (a board groups by Status)
#   4. link the project to the repo
#   5. print docs/agents/github-project.md, ready to save
#
# Usage: ./scripts/create-triage-board.sh [--owner LOGIN] [--title TITLE]
set -euo pipefail

OWNER="" ; TITLE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --owner) OWNER="$2"; shift 2 ;;
    --title) TITLE="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

# --- 0. preconditions -------------------------------------------------------
if ! gh auth status 2>&1 | grep -q "'project'"; then
  echo "error: the gh token lacks the 'project' scope." >&2
  echo "       run: gh auth refresh -s project --hostname github.com" >&2
  exit 1
fi

REPO_JSON="$(gh repo view --json name,owner,id)"
REPO_NAME="$(printf '%s' "$REPO_JSON" | jq -r .name)"
REPO_ID="$(printf '%s' "$REPO_JSON" | jq -r .id)"
[ -n "$OWNER" ] || OWNER="$(printf '%s' "$REPO_JSON" | jq -r .owner.login)"
[ -n "$TITLE" ] || TITLE="$REPO_NAME Triage"

echo "repo   : $REPO_NAME ($OWNER)"
echo "project: $TITLE"
echo

# --- 1. create the project --------------------------------------------------
PROJECT_JSON="$(gh project create --owner "$OWNER" --title "$TITLE" --format json)"
PROJECT_ID="$(printf '%s' "$PROJECT_JSON" | jq -r .id)"
NUMBER="$(printf '%s' "$PROJECT_JSON" | jq -r .number)"
URL="$(printf '%s' "$PROJECT_JSON" | jq -r .url)"
echo "1. created project #$NUMBER  $URL"

# --- 2. define the triage columns -------------------------------------------
# Update the built-in Status field rather than making our own single-select.
# Status is the field a board groups by out of the box, and GitHub's built-in
# workflows key off it (an item closing moves to the option they treat as done),
# and a field merely *named* Status would inherit none of that.
#
# Options are replaced wholesale: any option not listed here is dropped, which
# is why this only ever runs against a project the script just created. The
# stock Todo / In Progress / Done go away here.
STATUS_FIELD_ID="$(gh project field-list "$NUMBER" --owner "$OWNER" --format json \
  --jq '.fields[] | select(.name == "Status") | .id')"

gh api graphql -f query='
  mutation($field: ID!) {
    updateProjectV2Field(input: {
      fieldId: $field
      singleSelectOptions: [
        {name: "Inbox",           color: GRAY,   description: "Not triaged yet"}
        {name: "Triage",          color: YELLOW, description: "needs-triage: maintainer is evaluating"}
        {name: "Needs Info",      color: ORANGE, description: "needs-info: waiting on the reporter"}
        {name: "Ready for Agent", color: PURPLE, description: "ready-for-agent: brief attached, an agent can take it"}
        {name: "Ready for Human", color: BLUE,   description: "ready-for-human: needs a person"}
        {name: "Closed",          color: RED,    description: "wontfix: will not be actioned"}
      ]
    }) { projectV2Field { ... on ProjectV2SingleSelectField { id } } }
  }' -f field="$STATUS_FIELD_ID" > /dev/null
echo "2. Status field carries the six triage columns"

# --- 3. the default view becomes a board ------------------------------------
VIEW_ID="$(gh api graphql -f query='
  query($id: ID!) {
    node(id: $id) { ... on ProjectV2 { views(first: 1) { nodes { id } } } }
  }' -f id="$PROJECT_ID" --jq '.data.node.views.nodes[0].id')"

gh api graphql -f query='
  mutation($view: ID!) {
    updateProjectV2View(input: {viewId: $view, name: "Board", layout: BOARD_LAYOUT}) {
      projectV2View { id name layout }
    }
  }' -f view="$VIEW_ID" > /dev/null
echo "3. default view switched to a board, grouped by Status"

# --- 4. link it to the repo -------------------------------------------------
gh api graphql -f query='
  mutation($project: ID!, $repo: ID!) {
    linkProjectV2ToRepository(input: {projectId: $project, repositoryId: $repo}) {
      repository { nameWithOwner }
    }
  }' -f project="$PROJECT_ID" -f repo="$REPO_ID" > /dev/null
echo "4. linked to $OWNER/$REPO_NAME"

# --- 5. the config file -----------------------------------------------------
# IDs resolved above, followed by the rules and recipes template that ships
# next to this script. Together they are docs/agents/github-project.md.
OPTIONS="$(gh project field-list "$NUMBER" --owner "$OWNER" --format json \
  --jq '.fields[] | select(.name == "Status") | .options[] | "\(.name)\t\(.id)"')"
opt() { printf '%s\n' "$OPTIONS" | awk -F'\t' -v n="$1" '$1 == n {print $2}'; }
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo
echo "5. save everything below this line as docs/agents/github-project.md:"
echo "----------------------------------------------------------------------"
cat <<EOF
# Triage project board

Triaged issues and PRs are mirrored to a GitHub Projects (v2) board. This file holds the board's identity, the column mapping, and the rules and recipes for keeping it in step with the triage labels.

## Board

- **Owner**: \`$OWNER\`
- **Project number**: \`$NUMBER\`
- **Project title**: \`$TITLE\`
- **Project ID**: \`$PROJECT_ID\`
- **Project URL**: $URL
- **Status field ID**: \`$STATUS_FIELD_ID\`

## Status options

| Triage state role | Column          | Option ID  |
| ----------------- | --------------- | ---------- |
| _(untriaged)_     | Inbox           | \`$(opt Inbox)\` |
| \`needs-triage\`    | Triage          | \`$(opt Triage)\` |
| \`needs-info\`      | Needs Info      | \`$(opt "Needs Info")\` |
| \`ready-for-agent\` | Ready for Agent | \`$(opt "Ready for Agent")\` |
| \`ready-for-human\` | Ready for Human | \`$(opt "Ready for Human")\` |
| \`wontfix\`         | Closed          | \`$(opt Closed)\` |

EOF
cat "$HERE/github-project.md"
