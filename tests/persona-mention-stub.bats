#!/usr/bin/env bats
# Drift & compliance regression guard for the persona-mention thin caller stub.
#
# .github/workflows/persona-mention.yml is copied VERBATIM from the canonical
# org template (combsmith/.github → standards/workflows/persona-mention.yml)
# and must stay byte-identical across every adopting repo, modulo the per-repo
# channel pin on the `uses:` ref. Any other diff is drift — the silent-revert
# class of failure the fleet stub-drift monitor exists to catch (fleet_stub_drift.sh).
#
# The stub's behavior lives entirely in the central reusable; its `uses:` ref,
# trigger events, and job `permissions:` block are drift-protected and MUST NOT
# be edited in the caller (see the file's own "AGENTS — READ BEFORE EDITING"
# banner and ci-standards.md → Centralization tiers). This guard pins those
# invariants so drift is caught in CI rather than by the compliance audit.

STUB="${BATS_TEST_DIRNAME}/../.github/workflows/persona-mention.yml"

@test "persona-mention stub exists" {
  [ -f "$STUB" ]
}

@test "persona-mention stub is byte-identical to the canonical template" {
  # Inline canonical snapshot — update this heredoc whenever the central template
  # (combsmith/.github/standards/workflows/persona-mention.yml) changes.
  # The live canonical ships with a single trailing newline; printf '%s\n'
  # reproduces it exactly so this guard stays byte-faithful to the upstream blob.
  local canon
  canon="$(mktemp)"
  printf '%s\n' "$(cat << 'CANONICAL'
# ─────────────────────────────────────────────────────────────────────────────
# SOURCE OF TRUTH: combsmith/.github/standards/workflows/persona-mention.yml
# Standard:        combsmith/.github/standards/persona-standards.md (§4.1)
# Reusable:        combsmith/.github/.github/workflows/persona-mention-reusable.yml
#
# AGENTS — READ BEFORE EDITING:
#   • This file is a THIN CALLER STUB. All routing logic lives in the reusable
#     workflow above, and every per-persona decision lives in that persona's
#     manifest — not here and not in the reusable.
#   • You MUST NOT change: the `uses:` ref — it is pinned to the
#     `persona-mention/v1-stable` channel, a moving tag advanced centrally.
#     Never repoint it to `@main`, a SHA, or a frozen `@vX.Y.Z` (see
#     ci-standards.md → Reusable workflow versioning). Also do not change the
#     trigger events or the job-level `permissions:` block — reusable workflows
#     can be granted no more permissions than the calling job, so removing the
#     stanza breaks the reusable's gh API calls.
#   • Do NOT add a per-persona stub. ONE router serves every persona (§4.1);
#     a stub per agent is the drift the manifest exists to prevent.
#   • If you need different behaviour, open a PR against the reusable in the
#     central repo. A new release is rolled out by moving the channel tag
#     centrally — never by editing callers, so no fanout PR is needed.
# ─────────────────────────────────────────────────────────────────────────────
#
# Persona Mention Router — thin caller for the org-level reusable.
#
# Adopting this file makes every persona that enables the `mention` surface
# addressable in this repo as `@combsmith/<role>` — e.g.
#
#     @combsmith/qa-lead please assess test risk on this PR
#
# The handle is an org TEAM, never a user account: '@qa-lead' is a real GitHub
# account owned by an unrelated person (§4.1).
#
# To adopt: copy this file to .github/workflows/persona-mention.yml in your repo.
# Requires: GH_PAT_WORKFLOWS org secret (already present in combsmith org).
name: Persona — Mention Router

on:
  # issue_comment covers BOTH issues and PR conversation comments.
  issue_comment:
    types: [created]
  pull_request_review_comment:
    types: [created]
  # Discussions cannot run an agent inline (#571) — but this router only parses
  # and dispatches, and the agent itself runs on the resulting
  # repository_dispatch, which is exactly the bridge the manifest declares.
  discussion_comment:
    types: [created]
  # The router also serves the pull_request EVENT surface (#1165): it derives
  # which personas fire from their manifests' declared `pull_request` surfaces
  # and dispatches each PR-advisory, binding the same stop-marker / opt-out /
  # write-gate / trust-floor brakes as the mention path. This path activates
  # once the reusable at the pinned channel below advances to include it —
  # rollout is central (bump the channel, then sweep), never a stub edit.
  #
  # Subscribe only the actions a persona can declare on its `pull_request`
  # surface today: opened, ready_for_review, reopened. `synchronize` is NOT
  # subscribed — no persona declares it (qa-lead excludes it deliberately) and
  # the router would discard every synchronize event once the declared-events
  # gate is in, so subscribing it only burns a runner in every repo on every
  # push. It would be added here only if a persona declares it. (Reviewer
  # assignment, review_requested, is still correctly omitted — see below.)
  pull_request:
    types: [opened, ready_for_review, reopened]
# NOTE: reviewer assignment (pull_request/review_requested) is still NOT
# subscribed here, even though §4 says "Reviewer-assignment counts here too".
# The router has no path for it — and a trigger that fires into a router which
# ignores it is a dead trigger that only burns runs. Tracked as finding 10 in
# combsmith/.github#755; that trigger lands with its routing, not before.

permissions: {}

jobs:
  persona-mention:
    permissions:
      contents: read        # the reusable checks out its tooling repo — required,
                            # or the call fails at startup (a reusable is granted
                            # no more than the caller; persona-standards.md §5)
      issues: read
      pull-requests: read
    uses: combsmith/.github/.github/workflows/persona-mention-reusable.yml@persona-mention/v1-stable  # NOSONAR(githubactions:S7637) first-party channel ref
    secrets: inherit  # NOSONAR(githubactions:S7635) org secrets are scoped to first-party reusables
CANONICAL
)" > "$canon"
  run cmp -- "$canon" "$STUB"
  rm -f "$canon"
  [ "$status" -eq 0 ] || {
    echo "stub drifted from canonical: $output"
    return 1
  }
}

@test "uses: ref is pinned to the persona-mention/v1-stable channel" {
  grep -qF 'uses: combsmith/.github/.github/workflows/persona-mention-reusable.yml@persona-mention/v1-stable' "$STUB"
}

@test "uses: ref is not repointed to @main, a SHA, or a frozen @vN" {
  if grep -qE 'persona-mention-reusable\.yml@(main|[0-9a-f]{7,40}|v[0-9]+)([[:space:]]|$)' "$STUB"; then
    echo "Error: The uses: ref in $STUB is pointed to a forbidden ref (main, SHA, or frozen vN)." >&2
    echo "It must be pinned to the persona-mention/v1-stable channel." >&2
    return 1
  fi
}

@test "all four trigger events are present" {
  grep -qE '^  issue_comment:' "$STUB" || { echo "Missing issue_comment trigger"; return 1; }
  grep -qE '^  pull_request_review_comment:' "$STUB" || { echo "Missing pull_request_review_comment trigger"; return 1; }
  grep -qE '^  discussion_comment:' "$STUB" || { echo "Missing discussion_comment trigger"; return 1; }
  grep -qE '^  pull_request:' "$STUB" || { echo "Missing pull_request trigger"; return 1; }
  grep -qE '^    types: \[opened, ready_for_review, reopened\]' "$STUB" \
    || { echo "Missing pull_request opened/ready_for_review/reopened types"; return 1; }
}

@test "pull_request does not subscribe synchronize or review_requested" {
  if grep -qE '^    types: \[.*(synchronize|review_requested)' "$STUB"; then
    echo "pull_request must not subscribe synchronize or review_requested (dead triggers)"
    return 1
  fi
}

@test "top-level permissions are locked down to {}" {
  grep -q '^permissions: {}' "$STUB" || { echo "Top-level permissions are not locked down to {}"; return 1; }
}

@test "job grants contents/issues/pull-requests read and inherits secrets" {
  grep -qE '^      contents: read' "$STUB" || { echo "Missing contents: read permission"; return 1; }
  grep -qE '^      issues: read' "$STUB" || { echo "Missing issues: read permission"; return 1; }
  grep -qE '^      pull-requests: read' "$STUB" || { echo "Missing pull-requests: read permission"; return 1; }
  grep -qE '^    secrets: inherit' "$STUB" || { echo "Missing secrets: inherit"; return 1; }
}
