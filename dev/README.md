# Local LMS test setup

A Lyrion Music Server in Docker with a headless test player, used to reproduce plugin behaviour before anything goes upstream (see `AGENTS.md`). Nothing under `dev/` belongs in an upstream pull request.

All paths below are relative to `dev/`; run the commands from there.

## Layout

| Path | Versioned | What it is |
|---|---|---|
| `compose.yml` | yes | LMS container `lms-deezer-dev`, web UI on http://localhost:9000 |
| `plugin/` | no | git worktree of this repo, mounted read-only as the plugin `Deezer` |
| `config/` | no | LMS prefs, cache and logs (`config/logs/server.log`). **Holds the Deezer ARL** |
| `dist/` | no | test zips from `build-zip.sh` |
| `music/`, `playlist/` | no | empty LMS library folders |
| `*.sh`, `pacer.py` | yes | helpers and feedback loops |

## Where the ARL lives

The ARL is the Deezer login cookie, a credential. It is added once through the web UI (Settings → Plugins → Deezer → add account) and LMS stores it in `config/prefs/plugin/deezer.prefs` (key `arl:`). `config/` is gitignored. Never commit, share or print that file or unredacted `server.log` excerpts: older plugin versions log the ARL at INFO level (fork #9). When filtering such files on macOS, use `[[:space:]]`, not `\s`.

## First start

```sh
git -C .. worktree add dev/plugin --detach main   # or any branch to test
docker compose up -d
./player.sh &                                     # test player "hr8-test"
```

Then add the account in the web UI as above. Docker Desktop must share the repo's folder; `/Users` is shared by default, `/private/tmp` is not.

## Daily use

| Task | Command |
|---|---|
| Test another branch | `git -C plugin switch <branch>` (or `--detach <ref>`), then `./restart.sh` |
| Restart after a code change | `./restart.sh`: waits until the test player is connected and `refreshArl` really set the ARL, retries a failed start (fork #6) |
| Start the test player | `./player.sh &`; `PACE=6000000 ./player.sh &` plays about 10× real time |
| Send a JSON-RPC command | `./rpc.sh <playerid or ""> '<json array>'`, the test player is `02:00:00:00:00:08` |
| Build a test zip | `./build-zip.sh <ref> <version>` → `dist/Deezer-<version>-test.zip` plus its SHA-1 |
| Stop | `docker compose stop` and `pkill -f "n hr8-test"` |

`player.sh` runs the squeezelite binary from LyrionPlay (`/Applications/LyrionPlay.app`) with 24-bit output to `pacer.py`, which consumes it at `PACE` bytes per second instead of a sound card.

## Feedback loops

Each loop prints its evidence and ends with `VERDICT: green` (exit 0) or `VERDICT: RED` (exit 1); exit 2 means inconclusive. Check that the test player is connected first (`./restart.sh` does).

| Loop | Checks | Notes |
|---|---|---|
| `./hr81-queue.sh` | Playlist "Love Machine": tracks without rights and Fallback are left out, the 12 Fallback-only tracks are in, playback goes on after "Lovemachine" | needs `PACE=6000000 ./player.sh` |
| `./queue-status.sh` | Playlist "Love Machine" added by URL: every queue entry is a Deezer track (no sort link), `status` over the whole queue answers with a title for each, no "unblessed reference" error in `server.log` (fork #14) | |
| `./empty-image.sh` | Deezer's empty image (MD5 of ""): wipes LMS's cache (`config/cache/cache.db`) and restarts, then no icon in My collection → Tracks and no queued track's artwork may be the blank image (fork #15) | needs favourite tracks with that marker, as on the test account |
| `perl empty-image-test.pl [API.pm]` | Runs the plugin's own `getImageUrl` on track, album and playlist items with and without the empty image | no LMS needed; defaults to `plugin/API.pm` |
| `./next-fails.sh` | LMS core, no plugin: queue of local WAV, broken entry, local WAV, played from the first. The control (second entry a missing local file) must reach the third track; the verdict is the test case (second entry an unreachable `http://` URL), which stops in LMS 9.1+ because the failed song stays in the song queue (fork #17) | needs `PACE=6000000 ./player.sh`; generates its WAVs in `music/repro17/` |
| `./hr82-album.sh` | Boney M. album 108288 queues 14 tracks, Phil Carmen 248956 queues 0 | |
| `./hr81-cover.sh` | Cover of 4 Fallback-only tracks before, during and after playback, each cover id checked on the CDN | drops non-track queue entries first (the sort link on code without upstream #95) |
| `perl playable-tracks-test.pl [plugin dir]` | Runs the plugin's own `playlistTracks` with `_get` and `gwCall` stubbed: rights or Fallback decide, `readable` decides without a gw answer (no ARL, failed request, error answer), one gw request for 1200 tracks, Fallback cover also after the metadata refresh (fork #19) | no LMS needed; defaults to `plugin/` |
| `./hr9-loop.sh [DEBUG\|INFO\|WARN]` | Restarts LMS, re-adds the account, plays a track and Flow, then counts ARLs and session tokens in `server.log`. Prints counts and log locations, never values | leaves that log level in `config/prefs/log.conf` |
| `perl redact-test.pl [Async.pm]` | Runs the plugin's own `_redact`/`_dump` on fake secrets in every shape they reach the log: dumped hash, query string, Cookie header, JSON string inside a dump | no LMS needed; defaults to `plugin/API/Async.pm` |
| `./hr81-loop.sh <url> [start] [secs] [end]` | Timeline of the player state while playing `<url>`, to see where playback stops | |
| `./hr81-probe.sh <id>...` | Plays single track ids: plays or not, resolved Fallback id, no rights and no Fallback | |
| `./hr8-loop.sh <label> <url>` | Raw format from Deezer next to the bitrate LMS reports (fork #8) | needs the `[DEBUG-hr8]` probes, which are not in the code |
| `./hr8-scan.sh <id>...` | `FILESIZE_FLAC_24` and delivered format per track (fork #8) | needs the `[DEBUG-hr8]` probes |
