<div id="main" class="col-md-9" role="main">

# Create a run project directory

<div class="ref-description section level2">

Scaffolds one directory per matching run: numbered stage folders, each
with `batches/`, `interim/` and `logs/` subdirectories, a `README.md`
explaining what the stage does, and (for the LLM stages) a `PROMPT.md`
holding the agent instructions. Writes a `config.yml`, an empty
`manifest.csv`, an `AGENTS.md` describing how to orchestrate the whole
run, and a first `RUN-STATUS.md`.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_project_init(
  path,
  run_id = NULL,
  bmf = NULL,
  sam = NULL,
  config = np_config(),
  templates = TRUE,
  use = TRUE,
  overwrite = FALSE,
  quiet = FALSE
)
```

</div>

</div>

<div class="section level2">

## Arguments

-   path:

    Directory to create for this run.

-   run_id:

    Short run label recorded in reports and in the `run_id` column of
    every stage output. Defaults to `basename(path)`.

-   bmf:

    Optional path to (or vintage tag of) the reference used by this run,
    recorded in `00_bmf/SOURCE.md`. `NULL` leaves a placeholder.

-   sam:

    Optional path to a SAM extract to record in `00_sams/README.md`. The
    file is not copied.

-   config:

    An `np_config()` whose thresholds and weights are serialized to
    `config.yml`.

-   templates:

    Write the README / PROMPT / AGENTS documents. Default `TRUE`.

-   use:

    Set this project as the session default. Default `TRUE`.

-   overwrite:

    Overwrite existing template documents. Directories and data files
    are never removed. Default `FALSE`.

-   quiet:

    Suppress the summary message. Default `FALSE`.

</div>

<div class="section level2">

## Value

The project root, invisibly.

</div>

<div class="section level2">

## Details

All six stage folders are created unconditionally. Deploying a stage is
optional — one that never runs simply leaves its outputs absent, which
`np_project_status()` reports as *not run* rather than as an error.

</div>

<div class="section level2">

## Reference data is pointed at, not copied

The BMF is \~3.5 GB raw plus a \~470 MB normalized bundle, and is reused
across runs. `00_bmf/` therefore holds only `SOURCE.md` (vintage,
resolved path in the shared store, checksum, row count) and
`SIGNATURE.txt` (the `np_normalize_signature()` hash of the cached
artifact, so drift is detectable). The bytes stay in the
`np_data_path()` store. SAM is genuinely per-run, so `00_sams/raw/`
holds the real extract — paste one in, or let `np_fetch_sam()` download
into it.

</div>

<div class="section level2">

## See also

<div class="dont-index">

`np_project_status()` for the run status report, `np_project_path()` for
addressing files inside it, `np_data_init()` for the shared asset store.

</div>

</div>

<div class="section level2">

## Examples

<div class="sourceCode">

``` r
p <- file.path(tempdir(), "run-demo")
np_project_init(p, run_id = "demo", quiet = TRUE, use = FALSE)
list.files(p)
#>  [1] "00_bmf"        "00_sams"       "01_stage1"     "02_stage2"    
#>  [5] "03_stage3"     "04_final"      "AGENTS.md"     "README.md"    
#>  [9] "RUN-STATUS.md" "config.yml"    "manifest.csv" 
unlink(p, recursive = TRUE)
```

</div>

</div>

</div>
