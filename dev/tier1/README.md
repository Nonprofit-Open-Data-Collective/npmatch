# Tier-1 automated EIN screen

Cheapest tier of `dev/RESEARCH-PROTOCOL.md`, run over all MAYBE/NO/zero-candidate cases at ~zero external cost.

1. `build_bmf_index.R` — one-time: loads the **unified** BMF (`data-raw/bmf_unified_geocoded.csv`,
   active + inactive, same NCCS schema so no extra normalization), computes a normalized name key
   (`nk`), a de-spaced key (`nk_ds`, for STEP FORWARD -> STEPFORWARD), a DBA key, and an `active`
   flag (EIN present in the active file). Saves `data-dev/BMF-NAME-INDEX.rds` (~2 min).
2. `tier1_screen.R` — for each residual query: legal-form / entity gate (for-profit / government),
   then a name lookup against the index (exact, de-spaced, DBA/division; same-state preferred; a
   full-name variant tiebreak so Society != Foundation). Emits `data-dev/TIER1-DETERMINATIONS.csv`.
   A hit whose EIN is not `active` -> `nonprofit_not_in_bmf:inactive` (the unified-BMF payoff).

Escalate only the unresolved (`needs_escalation`) to Tier 2 (ProPublica) / Tier 3 (web).
