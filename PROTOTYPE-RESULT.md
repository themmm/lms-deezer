# Prototype result: Search and LMS search

Throwaway prototype on branch `prototype/search-menu` (`SearchPrototype.pm`). Tested in Material Skin against a local test LMS; the Squeezebox Radio is still to be tested.

## Questions and answers

**1. Can the LMS search offer Deezer matches that load only when tapped?**
Yes, but only one level down. A coderef `url` on the top-level "Deezer" node makes XMLBrowser skip its session id, and Material's `item_id:_<search>.N` then resolves into the first provider (the local library), leaving the page empty. The "Deezer" node therefore holds a static list: "All matches" plus one entry per Category, each loading lazily. No counts at that level (they can't be known synchronously); counts appear once opened (Q46 a).

**2. How should the Search result page look?**
Variant D wins in Material:
- Top result and each Category are Material section headers (`type => 'header'`) with an icon, followed by the first 3 matches.
- Counts are real totals: `pageSearch` caps both items (~20) and totals (e.g. 60 vs 280 episodes for "tkkg"), so one `search.music` call per Category with `nb=1` fetches the real total (Q45 b). The whole page rendered in about 0.9 s.
- Opening a Category pages through `search.music` (it honours `start`).
- Material ignores clicks on plugin header bars (`browse-page.js`, "Handled in showMore"); only its "More" link opens all matches. Accepted as Material's convention (Q48 a). The Top result header's "More" opens the top match's own page; `header-basic` is not usable for plugin menus because LMS still attaches its default go action.

Rejected: A (Categories with counts only), B (plain text headers with "show all" rows), C (Spotty-like flat list).

## Still open

- **Squeezebox Radio (Q47):** how D looks there (the radio likely ignores the header type, and D is ~29 rows for "tkkg"). Decide between D everywhere and D in Material / A on the radio after testing.
- **Icons:** the plugin's own PNGs (Radio stations, podcasts, episodes, Flow, Home, …) don't fit Material Skin well. Material replaces `html/images/*` paths with its own icon set, but shows plugin PNGs as they are. Rework the icons so they fit Material.
- **Recent searches:** the prototype kept them in memory only; the real implementation persists them per Account.
