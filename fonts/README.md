# Fonts

Vendored so the config layer can install them without a package manager or
`sudo`, and remove them on revert. Both are under the SIL Open Font License,
which permits redistribution; the licences are alongside.

| Family | Files | Used for | Licence |
|--------|-------|----------|---------|
| Inter | `Inter-Regular.ttf`, `Inter-Medium.ttf`, `Inter-SemiBold.ttf` | the shell, GTK apps, the group bar, Obsidian's interface | `OFL-Inter.txt` |
| Libre Baskerville | `LibreBaskerville.ttf` (variable weight) | note text in Obsidian; the reference sets its note in Baskerville | `OFL-LibreBaskerville.txt` |

`install/marvin` copies them to `~/.local/share/fonts/marvin/` and runs
`fc-cache`. Inter from the `inter-font` package works just as well if it is
already installed; these are only so that nothing has to be.
