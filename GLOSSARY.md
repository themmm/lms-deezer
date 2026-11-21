# Deezer for LMS

An LMS plugin that lets players browse, search and stream the Deezer catalog through a Deezer account. Deezer-specific concepts use the wording of Deezer's own web player; generic catalog types (artists, albums, tracks, playlists) use LMS's own words, so the plugin reads as one with the rest of LMS. Terms here are English; the localized UI labels live in `strings.txt`.

## Language

### Search

**Search**:
The single place in the plugin menu where a user types a term and gets matches from the whole Deezer catalog, across every Category.
_Avoid_: explore search, search per type

**LMS search**:
The server-wide search of LMS itself, which searches the local library and offers Deezer matches alongside. Distinct from the Search inside the plugin menu, though both show the same Deezer matches.
_Avoid_: global search

**Category**:
A kind of catalog item a Search can match, such as artist, album, track, playlist, Radio station or podcast. A Search groups its results by Category. (Deezer shows these as search filters; its own "Categories" heading on Explore means Channels, not this.)
_Avoid_: type, section, filter

**Top result**:
The single best match Deezer names for a Search, shown ahead of the Categories.
_Avoid_: top hit, best match

**Recent searches**:
The terms an Account has recently searched Deezer for, whether in the Search or by opening the Deezer matches of an LMS search, offered again as shortcuts. A term typed into the LMS search without opening its Deezer matches is not one.
_Avoid_: search history, last searches

### Listening

**Flow**:
Deezer's endless personal stream for an Account, optionally tuned to a mood or genre.

**Mix**:
An endless track sequence Deezer generates from a seed such as an artist, a track, a mood, a decade or a genre.
_Avoid_: Smart Radio, radio

**Radio station**:
A live broadcast station streamed through Deezer.
_Avoid_: radio, livestream, Smart Radio

**Channel**:
An editorial Deezer page on a theme (a genre, an occasion, podcasts), which groups playlists, albums and shows.
_Avoid_: category, section

### Menu

**Home**:
Deezer's personal start page for an Account, as Deezer composes it.
_Avoid_: main menu, start page

**Explore**:
The menu area for browsing the Deezer catalog beyond the Account's own content: charts, genres, Mixes, Radio stations, podcasts and Deezer's Channels.
_Avoid_: discover, browse

**Library**:
The menu area holding an Account's own content: favourites, My MP3s and Listening history.
_Avoid_: favourites, my music, collection

**Listening history**:
The tracks an Account has recently played on Deezer.
_Avoid_: history, recently played

### Accounts

**Account**:
A Deezer account configured in the plugin; one LMS server can hold several, and each player uses one.
_Avoid_: user, profile
