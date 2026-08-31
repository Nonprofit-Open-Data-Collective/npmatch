# npmatch run report

- **npmatch version:** 0.0.0.9000
- **generated:** 2026-08-06 15:10:00.320135
- **reference:** unified BMF (active+inactive, 3.69M)
- **source orgs considered:** 1,484
- **config:** method scoring; thresholds YES >= 0.78, MAYBE >= 0.65, min margin 0.05

## Matching process

Cascade passes (tight to loose):

| pass | criteria | candidates | yes | maybe | no | resolved | pending | median_yes_margin |
|---|---|---|---|---|---|---|---|---|
| exact-name                       | name == name (exact, same state) |   1173                           | 857                              |  81                              |   2                              | 857                              | 645                              | 0.9800000                        |
| exact-name-dba                   | name == dba  (exact, same state) |     20                           |  13                              |   3                              |   0                              |  13                              | 632                              | 0.9800000                        |
| exact-dba-name                   | dba == name  (exact, same state) |     30                           |  11                              |  10                              |   0                              |  11                              | 621                              | 0.9600000                        |
| exact-dba-dba                    | dba == dba   (exact, same state) |      4                           |   2                              |   1                              |   0                              |   2                              | 619                              | 0.9800000                        |
| token-state                   | shared name token, same state |  69544                        | 104                           | 201                           | 233                           | 104                           | 515                           | 0.3107692                     |
| token-concat                                      | shared token incl. de-spaced compound, same state | 101497                                            |  12                                               | 215                                               | 227                                               |  12                                               | 503                                               | 0.3787255                                         |
| token-crossstate             | shared name token, any state | 202915                       |   1                          | 208                          | 255                          |   1                          | 502                          | 0.4400000                    |

- **total candidates generated:** 375,183 (sum over passes)
- **unique candidate pairs (deduped union):** 304,274
- **avg candidates per source org:** 205.0 (max 14,634); 1484 of 1484 orgs got >=1 candidate

How surfaced matches were formed (match type of the chosen pick):

| match_type | Freq |
|---|---|
| dba | 129 |
| exact | 964   |
| name |  92  |
| token_overlap |  68           |

Name version used, source x reference (of the chosen pick):

| source_name | DBA | MAIN | TOKEN_OVERLAP |
|---|---|---|---|
| DBA  |  4   |   32 |  0   |
| DIVISION |  0       |   55     |  0       |
| MAIN | 38   | 1056 |  0   |
| TOKEN_OVERLAP |  0            |    0          | 68            |

- **vetoes on chosen picks:** 0 hard, 37 soft (soft caps at MAYBE)

## Outcome

| Tier | Count | Share |
|---|---:|---:|
| YES | 994 | 67.0% |
| MAYBE | 259 | 17.5% |
| NO | 231 | 15.6% |
| **Total** | **1,484** | |

- **YES margin (runner-up gap):** median 0.98, min 0.06
- Treating YES as an accepted link: 994 auto-accepted, 259 routed to review, 231 withheld.

## Operations

- **total:** 86.7 min
- **total:** 86.7 min

Files written:
- `EVAL-FRAME-1502-MERGED.csv`
- `MATCH-REPORT-1502.csv`
- `TRAINING-PAIRS-1502.csv`

## Next stage — review hand-off

The 259 MAYBE cases are the review queue. Generate per-case LLM adjudication
prompts with `np_as_prompts(np_route(res))`, or inspect one with
`np_as_prompt(routing, id)`. YES rows are auto-accepted; NO rows are withheld.
