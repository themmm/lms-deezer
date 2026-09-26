# Search runs on gw-light `deezer.pageSearch` and requires an ARL

The Suche and the Deezer matches in the LMS-Suche use the gw-light method `deezer.pageSearch`, because it is the only Deezer search that returns a Top-Ergebnis and every Kategorie (including live radio stations and editorial pages) with counts in one call. gw-light needs an ARL, so a Konto without one (a legacy OAuth-only account) gets a hint to re-add the account via ARL instead of a degraded search.

## Considered Options

- **Public `api.deezer.com/search/<type>`**: works without ARL, but has no Top-Ergebnis, no live radio stations or editorial pages, and needs one request per Kategorie.
- **pageSearch with public-API fallback for accounts without ARL**: rejected because such accounts can no longer be created (Settings only adds accounts from an ARL), and a second search path would have to be maintained for legacy cases only.
