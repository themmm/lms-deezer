# Deezer for LMS

An LMS plugin that lets players browse, search and stream the Deezer catalog through a Deezer account. Deezer-specific concepts use the wording of Deezer's own web player (DE/EN); generic catalog types (Künstler, Alben, Titel, Playlists) use LMS's own words, so the plugin reads as one with the rest of LMS.

## Language

### Suche

**Suche**:
The single place in the plugin menu where a user types a term and gets matches from the whole Deezer catalog, across every Kategorie.
_Avoid_: Explore-Suche, Typsuche, search per type

**LMS-Suche**:
The server-wide search of LMS itself, which searches the local library and offers Deezer matches alongside. Distinct from the Suche inside the plugin menu, though both show the same Deezer matches.
_Avoid_: globale Suche, global search

**Kategorie**:
A kind of catalog item a Suche can match, such as Künstler, Album, Titel, Playlist, Radiosender or Podcast. A Suche groups its results by Kategorie. (Deezer shows these as search filters; its own "Kategorien" heading on Entdecken means Channels, not this.)
_Avoid_: Typ, type, section, Filter

**Top-Ergebnis**:
The single best match Deezer names for a Suche, shown ahead of the Kategorien.
_Avoid_: Top-Treffer, best match

**Zuletzt gesucht**:
The terms a Konto has recently searched Deezer for, whether in the Suche or by opening the Deezer matches of an LMS-Suche, offered again as shortcuts. A term typed into the LMS-Suche without opening its Deezer matches is not one.
_Avoid_: Letzte Suchen, Suchverlauf, search history

### Hören

**Flow**:
Deezer's endless personal stream for a Konto, optionally tuned to a Mood or Genre.

**Mix**:
An endless track sequence Deezer generates from a seed such as an artist, a track, a mood, a decade or a genre.
_Avoid_: Smart Radio, Radio

**Radiosender**:
A live broadcast station streamed through Deezer.
_Avoid_: Radio, Livestream, Smart Radio

**Channel**:
An editorial Deezer page on a theme (a genre, an occasion, podcasts), which groups playlists, albums and shows.
_Avoid_: Kanal, Rubrik, Kategorie

### Menü

**Home**:
Deezer's personal start page for a Konto, as Deezer composes it.
_Avoid_: Hauptmenü, Startseite

**Entdecken**:
The menu area for browsing the Deezer catalog beyond the Konto's own content: Charts, Genres, Mixe, Radiosender, Podcasts and Deezer's Channels.
_Avoid_: Erkunden, Explore

**Bibliothek**:
The menu area holding a Konto's own content: favourites, Meine MP3s and Gehörte Songs.
_Avoid_: Favoriten, Meine Musik, Collection

**Gehörte Songs**:
The tracks a Konto has recently played on Deezer.
_Avoid_: Verlauf, History, Hörverlauf

### Konten

**Konto**:
A Deezer account configured in the plugin; one LMS server can hold several, and each player uses one.
_Avoid_: User, Account
