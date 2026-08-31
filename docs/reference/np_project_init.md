# Create a run project directory

Scaffolds one directory per matching run: numbered stage folders, each
with `batches/`, `interim/` and `logs/` subdirectories, a `README.md`
explaining what the stage does, and (for the LLM stages) a `PROMPT.md`
holding the agent instructions. Writes a `config.yml`, an empty
`manifest.csv`, an `AGENTS.md` describing how to orchestrate the whole
run, and a first `RUN-STATUS.md`.

## Usage

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

## Arguments

- path:

  Directory to create for this run.

- run_id:

  Short run label recorded in reports and in the `run_id` column of
  every stage output. Defaults to `basename(path)`.

- bmf:

  Optional path to (or vintage tag of) the reference used by this run,
  recorded in `00_bmf/SOURCE.md`. `NULL` leaves a placeholder.

- sam:

  Optional path to a SAM extract to record in `00_sams/README.md`. The
  file is not copied.

- config:

  An
  [`np_config()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_config.md)
  whose thresholds and weights are serialized to `config.yml`.

- templates:

  Write the README / PROMPT / AGENTS documents. Default `TRUE`.

- use:

  Set this project as the session default. Default `TRUE`.

- overwrite:

  Overwrite existing template documents. Directories and data files are
  never removed. Default `FALSE`.

- quiet:

  Suppress the summary message. Default `FALSE`.

## Value

The project root, invisibly.

## Details

All six stage folders are created unconditionally. Deploying a stage is
optional — one that never runs simply leaves its outputs absent, which
[`np_project_status()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_project_status.md)
reports as *not run* rather than as an error.

## Reference data is pointed at, not copied

The BMF is ~3.5 GB raw plus a ~470 MB normalized bundle, and is reused
across runs. `00_bmf/` therefore holds only `SOURCE.md` (vintage,
resolved path in the shared store, checksum, row count) and
`SIGNATURE.txt` (the
[`np_normalize_signature()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_normalize_signature.md)
hash of the cached artifact, so drift is detectable). The bytes stay in
the
[`np_data_path()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_data.md)
store. SAM is genuinely per-run, so `00_sams/raw/` holds the real
extract — paste one in, or let
[`np_fetch_sam()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_fetch_sam.md)
download into it.

## See also

[`np_project_status()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_project_status.md)
for the run status report,
[`np_project_path()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_project_path.md)
for addressing files inside it,
[`np_data_init()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_data.md)
for the shared asset store.

## Examples

``` r
p <- file.path(tempdir(), "run-demo")
np_project_init(p, run_id = "demo", quiet = TRUE, use = FALSE)
list.files(p)
#>  [1] "00_bmf"        "00_sams"       "01_stage1"     "02_stage2"    
#>  [5] "03_stage3"     "04_final"      "AGENTS.md"     "README.md"    
#>  [9] "RUN-STATUS.md" "config.yml"    "manifest.csv" 
unlink(p, recursive = TRUE)
```
