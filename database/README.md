# 🗄️ Database (Supabase) — enkelt forklart

## Kort svar: Brage trenger IKKE gjøre noe

Spillet **kobler seg allerede til en database automatisk**. Nøkkelen ligger inne i `index.html`, og innlogging, lagring, online-spillere og admin-krefter virker rett ut av boksen. Ingen oppsett nødvendig for å bruke den eksisterende databasen.

Og uten database funker spillet fint likevel — det lagrer da lokalt i nettleseren.

## 🔑 Om nøkler — hva er trygt?

| Nøkkel | I koden? | Hvorfor |
|---|---|---|
| **Anon / publishable** (`sb_publishable_…`) | ✅ JA (ligger i `index.html`) | **Trygt.** Den er laget for å være offentlig. Databasen har «deny-all» sikkerhet (RLS), og ALL tilgang går gjennom funksjoner som selv sjekker hvem du er. Nøkkelen kan altså ikke misbrukes til å lese/ødelegge data. |
| **Secret / service_role / management-token** (`sbp_…`) | ❌ ALDRI | Gir full tilgang til hele databasen. Skal aldri ligge i et offentlig repo. Vi har holdt den ute. |

Så: **ja, vi kan ha med nøkkelen** — men bare den trygge (anon). Det er nettopp derfor Brage slipper å gjøre noe: den trygge nøkkelen er allerede der.

## 🆕 Vil du lage din EGEN database?

Bare hvis du vil ha din helt egen (valgfritt):

1. Lag et gratis prosjekt på [supabase.com](https://supabase.com)
2. Åpne **SQL Editor** → lim inn hele **`setup.sql`** → Run
3. I `index.html` (øverst i den store `<script>`-blokka, søk etter `window.BX_DB`): bytt `URL` og `KEY` til ditt nye prosjekt sin URL + anon-nøkkel

Ferdig. `setup.sql` er komplett og trygg å kjøre (idempotent — tåler å kjøres flere ganger).

## ℹ️ Én ting å vite

Admin-koden ligger i spill-koden (klient-siden), så den som leser koden kan bli admin på den delte databasen. For et lite spill blant venner er det greit. Blir det et problem, kan admin-sjekken flyttes inn i databasen senere — spør AI-en om hjelp med det.
