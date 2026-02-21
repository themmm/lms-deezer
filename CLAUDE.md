# Project Notes for Claude

## Workflow
- Create a commit after every meaningful change to source files
- Commit messages in English, format `type: short description` (e.g. `fix:`, `feat:`, `refactor:`)
- Add a commit body for non-trivial changes explaining why, not what
- Create commits with `GIT_EDITOR=true git commit -F <tempfile>` (no interactive editor)

## Technical
- LMS plugin for Deezer (Lyrion Music Server / Logitech Media Server)
- Perl codebase, no build step required
- Server restart required for changed `.pm` files to be reloaded

## Architecture
- `API/Async.pm`: Main API, async calls, session state in `%contexts{userId}`
- `API/Auth.pm`: OAuth flow and CBC bootstrap
- `Settings.pm`: Web UI for account management
- `ProtocolHandler.pm`: Blowfish/CBC decryption of audio streams
- Accounts stored in LMS prefs under `plugin.deezer` → `accounts`
- ARL and SID are always set explicitly in the Cookie header; the LMS cookie jar
  is cleared before each deezer.com request to prevent cross-account contamination
