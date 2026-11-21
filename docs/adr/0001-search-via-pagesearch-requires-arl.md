# Search runs on gw-light `deezer.pageSearch` and requires an ARL

The Search and the Deezer matches in the LMS search use the gw-light method `deezer.pageSearch`, because it is the only Deezer search that returns a Top result and every Category (including Radio stations and editorial pages) with counts in one call. gw-light needs an ARL, so an Account without one (a legacy OAuth-only account) gets a hint to re-add the account via ARL instead of a degraded search.

## Considered Options

- **Public `api.deezer.com/search/<type>`**: works without ARL, but has no Top result, no Radio stations or editorial pages, and needs one request per Category.
- **pageSearch with public-API fallback for accounts without ARL**: rejected because such accounts can no longer be created (Settings only adds accounts from an ARL), and a second search path would have to be maintained for legacy cases only.
