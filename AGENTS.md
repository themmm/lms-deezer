# lms-deezer

Deezer plugin for Lyrion Music Server (LMS), written in Perl with no build step. LMS loads `.pm` files only at startup, so a changed module takes effect after a server restart.

## Language

Everything in the repo is English: code, comments, log messages, docs, `GLOSSARY.md`, ADRs, commit messages. The only exception is localized UI text, which lives in `strings.txt`; user-visible labels go there as keys, never as hard-coded strings in a module. Conversation with the user may be in German; that never carries over into files.

## Upstream

This repo is a fork of `philippe44/lms-deezer` (remote `upstream`); fork features are meant to go back upstream as pull requests.

- Where upstream already has a label for a concept, use upstream's wording in every language. Never change the text of an existing upstream key in `strings.txt`; that only creates merge conflicts and a second wording for the same thing.
- Keys for fork-only features are fine. They travel in the upstream pull request that brings that feature.
- Nothing goes upstream (pull request, issue or claimed bug) on the strength of reading the code alone. Reproduce it on a running LMS first and record the evidence in a fork issue; only then take it upstream. The local LMS, its test player and the feedback loops live in `dev/` (see `dev/README.md`); nothing under `dev/` goes into an upstream pull request.
- Missing translations of upstream keys go upstream too, but collected into one pull request, never one key at a time, so the maintainer is not flooded with pull requests.

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
