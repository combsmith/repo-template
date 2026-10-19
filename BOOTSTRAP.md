# Bootstrap a new repo from this template

This file is the **customization runbook** for a repository that was just created
from `combsmith/repo-template` with **Use this template**. It is written so an
agent (Claude Code, Copilot coding agent, Codex) can execute it end to end from
a handful of inputs, with a human doing only the org-admin steps it cannot.

Everything the template ships is already org-compliant. Bootstrapping is the
small set of edits that turn the generic scaffold into *this* project, plus the
removal of the files that only exist to test the template itself.

Run the steps in order. Each step says what to edit, what to leave alone, and
how to check it. When every step is done, delete this file (step 10).

---

## 0. Inputs — collect these before editing anything

| Input | Example | Used by |
|---|---|---|
| `REPO` — `owner/name` of the new repo | `combsmith/hive-health` | `sonar-project.properties`, `README.md`, `copilot-instructions.md`, `feature-ideation.yml` |
| `DESCRIPTION` — one sentence, what the repo is | `Beehive telemetry dashboard and alerting service` | `README.md`, `copilot-instructions.md`, repo description |
| `STACK` — one of `frontend`, `backend-go`, `backend-python`, `backend-rust`, `fullstack`, `infra-terraform`, `none` | `backend-python` | `dependabot.yml`, `ci.yml`, `copilot-setup-steps.yml`, `.gitignore` L2, `.github/instructions/` |
| `PROJECT_CONTEXT` — 3 to 5 sentences: product, target users, competitive landscape | see `feature-ideation.yml` header | `feature-ideation.yml` (`project_context`) |
| `BMAD` — `yes` for product repos (org default), `no` for data/tooling repos | `yes` | step 8 |

Rules for an agent:

- If `STACK` or `PROJECT_CONTEXT` is missing, **ask once** and stop. Do not infer
  the stack from an empty repo.
- `none` is valid for `STACK` (docs-only or not-yet-decided repos): keep the
  shipped shell-based `ci.yml` and the `frontend` Dependabot file, and revisit
  when code lands.
- Work on a branch and open one PR titled `chore: bootstrap from repo-template`.
  Never push to `main`.

---

## 1. File inventory — what to do with every shipped file

**Keep verbatim** (managed by org automation; the standards sweep re-syncs them
by PR, and the compliance audit flags any hand edit as drift):

| Path | Why it is untouchable |
|---|---|
| `.github/workflows/add-to-project.yml`, `agent-shield.yml`, `auto-rebase.yml`, `dependabot-automerge.yml`, `dependabot-rebase.yml`, `dependency-audit.yml`, `dev-lead.yml`, `initiative-driver.yml`, `persona-mention.yml`, `pr-auto-review.yml`, `pr-review-mention.yml` | Thin caller stubs. Behaviour lives in the org reusables; the `uses:` pin is moved centrally. `agent-shield.yml` is additionally a security boundary agents must never modify. |
| `.github/CODEOWNERS` | `* @combsmith/org-leads` must stay the first owner on every line. Add path lines only *after* it. |
| `CLAUDE.md`, `SECURITY.md`, `LICENSE` | Org pointers and license. |
| `.gitignore` — the block between `>>> BEGIN combsmith secrets baseline` and `<<< END` | Hash-checked by the compliance audit. Edit only **below** the END marker. |
| `.gitleaks.toml` | Keep the file; you may only **append** allowlist paths under `[allowlist]`. |
| `.github/workflows/sonarcloud.yml` | Keep as shipped; the `SonarCloud` job name is a required check. |

**Customize** (step numbers below):

| Path | Step |
|---|---|
| `.github/dependabot.yml` | 2 |
| `.github/workflows/ci.yml` | 3 |
| `.github/workflows/copilot-setup-steps.yml` | 4 |
| `.github/workflows/feature-ideation.yml` | 5 |
| `sonar-project.properties` | 6 |
| `README.md`, `AGENTS.md`, `.github/copilot-instructions.md`, `.github/instructions/` | 7 |
| `.gitignore` (below the END marker), `.worktreeinclude` | 7 |

**Delete** (template-only; they exist to test the template repo itself):

| Path | Why |
|---|---|
| `tests/*.bats` | Regression guards for *this template's* stubs and its shell `ci.yml`. In a product repo they fail the moment `ci.yml` is customized, and the org compliance audit already guards the stubs. Keep individual files only if `STACK` is shell and you want them. If PR automation asks for the `ack-test-deletion` label, add it: these are not product tests. |
| `standards/rulesets/pr-quality.json` | Codified copy used by the template's tests. The live ruleset is applied to the new repo by `bootstrap-new-repo.sh` (step 9). |
| `BOOTSTRAP.md` | This runbook, once complete (step 10). |

---

## 2. Dependabot — pick the stack

Replace `.github/dependabot.yml` with the canonical file for `STACK`
(`frontend` ships by default). Every stack file already contains the required
`github-actions` entry; do not add a second one.

```bash
gh api repos/combsmith/.github/contents/standards/dependabot/${STACK}.yml \
  --jq '.content' | base64 -d > .github/dependabot.yml
```

Adjust only `directory:` paths if manifests are not at the repo root. Policy:
[`standards/dependabot-policy.md`](https://github.com/combsmith/.github/blob/main/standards/dependabot-policy.md).

Check: `python3 -c 'import yaml,sys; yaml.safe_load(open(".github/dependabot.yml"))'` exits 0.

---

## 3. `ci.yml` — replace the shell checks with your stack's checks

`.github/workflows/ci.yml` ships with three jobs. Keep all three job ids and
display names; two of them are org required checks and the third is this repo's
required CI check:

| Job id | `name:` | What to change |
|---|---|---|
| `build-and-test` | `build-and-test` | Replace the *Install tools*, *Lint shell scripts* and *Run bats tests* steps with your stack's lint, format check, type check and unit tests. |
| `secret-scan` | `Secret scan (gitleaks)` | Nothing. |
| `coverage` | `coverage` | Replace the shell/bats block with your stack's coverage command (examples are in the file's trailing comment). It must stay green when no tests exist yet. |

Do **not** change: the workflow `name: CI` (`pr-auto-review.yml` waits on that
name), the triggers, `permissions: {}` at top level with `contents: read` per
job, the `concurrency` block, or `timeout-minutes` on every job. SHA-pin every
third-party action (`uses: owner/action@<40-char sha> # vX.Y.Z`). Keep the
retry-with-increasing-backoff pattern for any network install step; the Fleet
Monitor flags flaky installs.

Stack patterns and SHA-pinned setup actions:
[`ci-standards.md` → Workflow Patterns by Tech Stack](https://github.com/combsmith/.github/blob/main/standards/ci-standards.md#workflow-patterns-by-tech-stack).

Check: `python3 -c 'import yaml; yaml.safe_load(open(".github/workflows/ci.yml"))'`
exits 0, and the three job ids above are still present.

---

## 4. `copilot-setup-steps.yml` — enable your stack block

In `.github/workflows/copilot-setup-steps.yml`, uncomment the block(s) matching
`STACK` (Node/npm, Node/pnpm, Go, Python) and **delete** the blocks that do not
apply. Do not touch the job name, the fork guard, the triggers, or the
*Verify environment* step. For `STACK=none`, leave the file as shipped.

---

## 5. `feature-ideation.yml` — set `project_context`

Replace the `TODO:`/`Example:` placeholder under `project_context:` with
`PROJECT_CONTEXT`. This is the only edit allowed in that file; the compliance
audit raises `feature-ideation-placeholder-context` until it is done.

Check: `grep -c 'TODO: Replace this' .github/workflows/feature-ideation.yml` prints `0`.

---

## 6. `sonar-project.properties` — set the project key

```properties
sonar.projectKey=combsmith_<name>      # REPO with "/" replaced by "_"
sonar.organization=combsmith
sonar.sources=<source dirs>            # e.g. src  or  .  for small repos
sonar.tests=<test dir>                 # omit if none yet
sonar.exclusions=**/node_modules/**,**/vendor/**,**/dist/**
```

Remove the two "Customize…" comment lines at the top. SonarCloud is enabled
org-wide; no console step is needed for a public repo.

---

## 7. Docs and per-repo config

1. **`README.md`** — replace everything above the `---` rule with the project's
   own title, `DESCRIPTION`, quick start and usage. **Keep the
   `## 💼 Commercial Support & Enterprise Services` section verbatim**; it is
   org-standard text.
2. **`AGENTS.md`** — keep the org-standards pointer paragraph. Replace the
   template-specific sections with this repo's: project overview and
   architecture, `## Local Development Commands`, `## Required Environment
   Variables`, testing approach and coverage threshold, code style. The two
   `##` headings named here are mandatory per the org `AGENTS.md`.
3. **`.github/copilot-instructions.md`** — rewrite for this repo following the
   required sections in
   [`copilot-instructions-standard.md`](https://github.com/combsmith/.github/blob/main/standards/copilot-instructions-standard.md)
   (About, Tech Stack, Project Structure, Local Dev Commands, Required
   Environment Variables, Testing Framework, Repo-Specific Overrides, Org
   Standards). Keep it to about two pages.
4. **`.github/instructions/`** — for each language in `STACK`, copy the
   canonical path-scoped file and list it under `## Org Standards` in
   `copilot-instructions.md`:

   ```bash
   mkdir -p .github/instructions
   for lang in python shell; do   # pick from: typescript javascript python go terraform shell
     gh api repos/combsmith/.github/contents/.github/instructions/${lang}.instructions.md \
       --jq '.content' | base64 -d > .github/instructions/${lang}.instructions.md
   done
   ```

5. **`.gitignore`** — append the matching
   [github/gitignore](https://github.com/github/gitignore) template **below**
   the `<<< END combsmith secrets baseline <<<` marker. Never re-ignore a path
   the baseline negates (`!.env.example`, `!*.crt`, `!*.pub`, `!*.enc.yaml`).
6. **`.worktreeinclude`** (optional) — list gitignored files agents need copied
   into worktrees, typically `.env` and `.env.local`.
7. **`.gitleaks.toml`** — append allowlist paths only for real false positives
   (test fixtures, generated keys). Keep the `_bmad/` entry.

Check: `grep -n "repo-template" README.md AGENTS.md .github/copilot-instructions.md sonar-project.properties`
prints nothing. (Workflow stub headers legitimately mention `repo-template`;
leave those.)

---

## 8. Remove template-only files; install BMAD if a product repo

```bash
git rm -r tests standards BOOTSTRAP.md        # keep tests/ only for a shell stack
```

If `BMAD=yes`, install the BMAD Method (org standard for product repos:
spec-driven development, planning artifacts in `_bmad-output/`):

```bash
npx bmad-method install
```

`_bmad/` is already allowlisted in `.gitleaks.toml`. Commit the generated files.

---

## 9. Org-admin steps (human; the agent cannot do these)

Report these to the maintainer as the hand-off. None of them require code changes.

| # | Action | Command / where |
|---|---|---|
| 1 | Apply repo settings, GHAS + push protection, the `pr-quality` and `code-quality` rulesets, the standard label set, CODEOWNERS verification, and confirm the release ring. | In a checkout of `combsmith/.github`: `DRY_RUN=true bash scripts/bootstrap-new-repo.sh REPO`, review, then `bash scripts/bootstrap-new-repo.sh REPO`. Needs a classic PAT with `repo` + `admin:org`. |
| 2 | Set the repo description and topics; enable Discussions and create the **Ideas** (💡) and **General** (💬) categories. | `gh repo edit REPO --description "DESCRIPTION"`; categories via Settings → Discussions (no REST API). |
| 3 | Add the new repo to the advisory review bots' per-repo lists. | Gemini Code Assist: Google Cloud → Developer Connect (`code-assist-<org>`, `us-east1`) → Link Repositories. Codex: ChatGPT Codex connector settings. Verify with a throwaway PR and `/gemini review`. CodeRabbit and SonarCloud need no per-repo step. |
| 4 | Confirm CodeQL default setup is `configured` (done by step 1; verify). | `gh api repos/REPO/code-scanning/default-setup --jq .state` |

Org secrets (`SONAR_TOKEN`, `APP_ID`/`APP_PRIVATE_KEY`, `GH_PAT_WORKFLOWS`,
`CLAUDE_CODE_OAUTH_TOKEN`, `INITIATIVES_APP_*`) are inherited; nothing to set per
repo. The Claude and CodeRabbit GitHub Apps are installed org-wide.

---

## 10. Done criteria

- [ ] `.github/dependabot.yml` is the `STACK` file (or `frontend` for `none`).
- [ ] `ci.yml` runs the stack's lint / format / typecheck / tests / coverage; jobs `build-and-test`, `Secret scan (gitleaks)`, `coverage` still exist; workflow is still named `CI`.
- [ ] `copilot-setup-steps.yml` has exactly the stack block(s) enabled.
- [ ] `feature-ideation.yml` carries a real `project_context`.
- [ ] `sonar-project.properties` names `combsmith_<name>`.
- [ ] `README.md`, `AGENTS.md`, `copilot-instructions.md` describe this repo; language instruction files copied and listed.
- [ ] `tests/*.bats`, `standards/`, and `BOOTSTRAP.md` removed (unless shell stack).
- [ ] No stub listed under *Keep verbatim* has a diff.
- [ ] The bootstrap PR is green on `build-and-test`, `Secret scan (gitleaks)`, `coverage`, `SonarCloud`, `CodeQL`, `agent-shield / AgentShield`, `dependency-audit / Detect ecosystems`.
- [ ] Hand-off message to the maintainer lists the four org-admin actions in step 9.

---

## Why the template looks the way it does

- **Stubs are a distribution artifact.** Everything under *Keep verbatim* is
  regenerated from [`combsmith/.github`](https://github.com/combsmith/.github)
  `standards/` by `seed-repo-template.sh` (in `combsmith/.github-private`) and
  kept in sync in every repo by `deploy-standard-workflows.sh`. Fix the
  standard, not the copy.
- **Framework subtrees (`frameworks/`) are not seeded.** `bmad-method`,
  `spec-kit` and `gsd` are `git subtree` tooling maintained in
  `combsmith/.github-private`; add one on demand with `git subtree add`.
- **App installs are org-level.** The bootstrap script only disables the
  Claude/CodeRabbit check-suite auto-trigger on the new repo so queued-but-never-
  completed suites cannot block auto-merge.

Standards index: [`combsmith/.github/AGENTS.md`](https://github.com/combsmith/.github/blob/main/AGENTS.md).
