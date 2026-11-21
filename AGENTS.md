# lms-deezer

Deezer plugin for Lyrion Music Server (LMS), written in Perl with no build step. LMS loads `.pm` files only at startup, so a changed module takes effect after a server restart.

## Commits

Commit after every meaningful change to source files. Message in English, `type: short description` (`fix:`, `feat:`, `refactor:`, `docs:`), plus a body explaining why for non-trivial changes. Write the message to a temp file and run `GIT_EDITOR=true git commit -F <tempfile>`.

## Accounts and sessions

- Accounts live in LMS prefs `plugin.deezer` → `accounts`; per-account session state lives in `%contexts{userId}` in `API/Async.pm`.
- Every deezer.com request sets ARL and SID explicitly in the Cookie header after clearing the LMS cookie jar for `.deezer.com`, so one account's cookies never reach another account's request. New requests follow the same pattern.

## Agent skills

### Issue tracker

GitHub Issues on the fork `themmm/lms-deezer`, never upstream. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.
