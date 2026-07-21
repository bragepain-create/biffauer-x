# 🏰 BIFFAUER X

Et tower-defense-spill laget av **Brage** 🎮

Forsvar slottet ditt mot bølger av monstre gjennom fem tidsaldre — fra 🦴 primitiv → 🪨 steinalder → 🔫 krutt → 💣 militær → ⚡ sci-fi.

## ▶️ Spill nå

Åpne `index.html` i nettleseren — det er hele spillet i én fil (ingen installasjon).

For å spille online kan du slå på **GitHub Pages** (Settings → Pages → Branch: `main` → `/root`), så blir spillet tilgjengelig på:
`https://bragepain-create.github.io/biffauer-x/`

## ✨ Hva spillet har

- 🦸 **Mange helter** å kjøpe og plassere — bue, magi, pistol og stjernehelter (noen krever høyt level!)
- 🃏 **Kort-system** — trekk krefter før du starter (flere kort jo høyere level)
- ⚙️ **Vanskelighetsgrad** — Lett / Normal / Vanskelig for monstrene
- 🐱 **Skins** — slott, bakgrunn og fort (admin har hele katte-settet!)
- 🖱️ **10 stjerne-cursor-skins** (på PC)
- 😱 **Jump scares** (admin) med justerbar lyd og lys
- 🧮 **Matte-modus** — regn for å låse opp krefter
- 🌐 **Multiplayer** (via PeerJS) og innlogging med lagret progresjon

## 🗄️ Database (valgfritt)

Innlogging og lagring på tvers av maskiner bruker Supabase. SQL-oppsettet ligger i `database/`:

1. `fase1-database.sql` — grunnoppsett (brukere, lagring, mynter)
2. `admin-features.sql` — broadcast, live-spillere, innsendinger
3. `passord-reset.sql` — "glemt passord"-forespørsler
4. `coins-start-0.sql` — nye spillere starter med 0 mynter

Kjør dem i Supabase SQL Editor. Uten database fungerer spillet fint lokalt (lagrer i nettleseren).

## 🛠️ Teknisk

Én HTML-fil · React 18 + PeerJS fra CDN · ingen byggesteg · vanlig JavaScript (canvas-motor).

## 🤖 Skal en AI hjelpe med utviklingen?

Les **[`AGENTS.md`](AGENTS.md)** først — en kort onboarding om Brage, symbiosen, og hvordan AI-en skal jobbe (én feature av gangen · svar kort på norsk · test/render-verify før du sier noe funker · ta godt vare på skaperen).

## ⬇️ Fortsette utviklingen

Klon repoet, åpne `index.html` i nettleseren — det er hele spillet. Rediger fila, lagre, oppdater nettleseren. Ingen installasjon. Del gjerne endringer tilbake via GitHub.

---

Laget med kjærlighet av **Brage** 🌟
