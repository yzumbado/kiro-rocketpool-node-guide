# Active Tasks

Short-term work in progress. Updated every session.
For long-term deferred items see `10-pending-improvements.md`.
For phase progress see `session-state.md`.

---

## In Progress

| # | Task | Owner | Notes |
|---|---|---|---|
| T1 | Update `setup-mac-ssh.sh.template` — remove stale `firstrun.log` poll (M3 from security audit), add explicit human approval flow before running `harden-pi.sh` | Kiro Dev | Security audit finding M3. Approval flow must explain: what harden-pi.sh does, that it runs as root, that it disables password auth permanently, how future access works. |
| T2 | Update project documentation — `session-state.md`, `00b-jump-host-setup.md`, guide README, root README to reflect current script architecture (minimal flash + agent hardening) | Kiro Dev | Docs still reference old firstrun.sh approach in some places |

---

## Blocked

| # | Task | Blocked by | Notes |
|---|---|---|---|
| — | | | |

---

## Recently Completed

| # | Task | Completed | Notes |
|---|---|---|---|
| C1 | Minimal flash refactor — remove firstrun.sh, split into flash + harden-pi.sh | This session | Major architecture change |
| C2 | Security audit report | This session | `SECURITY-AUDIT.md` created |
| C3 | `kiro-dev.md` steering file | This session | Guide maintainer persona |
| C4 | `harden-pi.sh.template` created | This session | All hardening now runs over SSH |
| C5 | Fix all 12 backlog issues from code review | This session | See commit history |

---

## How to Use This File

**When you discover a new task during a session:**
1. Add it to "In Progress" immediately with a clear description
2. Note the context (what triggered it, what file it affects)
3. Commit the TASKS.md update alongside any related code changes

**When a task is complete:**
1. Move it to "Recently Completed" with the date
2. Update any related documentation
3. Commit

**When starting a new session:**
1. Read this file first
2. Pick up In Progress items before starting new work
3. Update the session log in `session-state.md`

**Pruning:** Move items older than 2 weeks from "Recently Completed" to the git history (they're captured in commits). Keep this file focused on current work.

---

## Developer Session Log

*Notes from Kiro Dev sessions — what was built, what was decided, what changed.*

| Date | Summary |
|---|---|
| Apr 2026 | Major architecture refactor: removed firstrun.sh from flash process. Flash now minimal (userconf.txt + ssh file only). All hardening moved to harden-pi.sh which runs over SSH after boot. Created SECURITY-AUDIT.md, kiro-dev.md, TASKS.md. Fixed 12 backlog issues from code review. Established three-tier task tracking system. Created kiro-for-teams/HANDOFF.md as seed for new project. |
