#!/usr/bin/env bash
# Create a Kanban-shaped GitHub Projects (v2) board for /triage.
#
# gh project create has no --template and always makes a Table view, so this
# builds the Kanban shape through GraphQL instead:
#
#   1. create the project, named after the git repo
#   2. replace the stock Status options with the triage columns
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

# --- 2. triage columns replace Todo / In Progress / Done ---------------------
# Options are replaced wholesale: any option not listed here is dropped. Safe on
# a project this script just created, destructive on one that already has cards.
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
OPTIONS="$(gh project field-list "$NUMBER" --owner "$OWNER" --format json \
  --jq '.fields[] | select(.name == "Status") | .options[] | "\(.name)\t\(.id)"')"
opt() { printf '%s\n' "$OPTIONS" | awk -F'\t' -v n="$1" '$1 == n {print $2}'; }

echo
echo "5. save this as docs/agents/github-project.md:"
echo
cat <<EOF
# Triage project board

- **Owner**: \`$OWNER\`
- **Project number**: \`$NUMBER\`
- **Project title**: \`$TITLE\`
- **Project ID**: \`$PROJECT_ID\`
- **Project URL**: $URL
- **Status field ID**: \`$STATUS_FIELD_ID\`

## Status options

| Triage state role | Column          | Option ID           |
| ----------------- | --------------- | ------------------- |
| _(untriaged)_     | Inbox           | \`$(opt Inbox)\`
| \`needs-triage\`    | Triage          | \`$(opt Triage)\`
| \`needs-info\`      | Needs Info      | \`$(opt "Needs Info")\`
| \`ready-for-agent\` | Ready for Agent | \`$(opt "Ready for Agent")\`
| \`ready-for-human\` | Ready for Human | \`$(opt "Ready for Human")\`
| \`wontfix\`         | Closed          | \`$(opt Closed)\`

## Other fields maintained by triage

_(none)_
EOF
