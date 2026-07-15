-- ══════════════════════════════════════════════════════════════
-- BIFFAUER X · Nye spillere starter med 0 skin-coins (ikke 200/999)
-- Trygt å kjøre — sletter INGEN data. Endrer bare default for nye kontoer.
-- (Valgfritt) Fjern kommentaren på siste linje for å nulle ALLE eksisterende også.
-- ══════════════════════════════════════════════════════════════

alter table coins alter column amount set default 0;

-- update coins set amount = 0;   -- <- ta vekk "--" foran hvis du vil nulle alle nå
