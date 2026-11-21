# A track's playability comes from its rights and Fallback, not from `readable`

Playlists and albums list only Playable tracks, and the plugin decides that from gw-light `song.getListData`: a track is playable if it has streaming rights or a Fallback. The public API's `readable` flag is wrong in both directions (album 108288: all 14 tracks `readable:false`, all 14 play; album 248956: all 9 `readable:true`, none plays), and a single unplayable track queued as the next track stops playback altogether, because of an LMS core bug in `StreamingController::_NextIfMore` (reproduced in fork issue #11). One gw request covers a whole list; 1669 ids were answered in one call.

## Considered Options

- **Filter by `readable`** (upstream 3.4.0 for playlists): hides playable tracks and lets unplayable ones through, so playback still stops.
- **Show everything and let playback skip failures**: depends on the LMS core bug being fixed and on every user's LMS version.
- **A setting to turn the check on** (the first version of upstream PR #82): rejected; the check is cheap and correct, and with it off albums show tracks that stop playback.

## Consequences

- Without a gw answer (no ARL in the Account's context yet, or a failed request) playlists fall back to `readable` and albums keep every track, so a gw outage never empties a list.
- A track that plays only through its Fallback always shows the Fallback's cover, because its own image id is often empty or points to a removed image. Title, artist and album still come from the original track.
