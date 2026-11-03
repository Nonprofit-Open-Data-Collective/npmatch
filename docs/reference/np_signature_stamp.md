# Stamp a run's normalizer provenance

Writes `00_bmf/SIGNATURE.txt`: the
[`np_normalize_signature()`](https://nonprofit-open-data-collective.github.io/npnormalize/reference/np_normalize_signature.html)
fingerprint of the normalizer that built the cached normalized bundle a
run points at, together with the npnormalize release that introduced
that fingerprint.

## Usage

``` r
np_signature_stamp(
  project = np_project_root(),
  signature = np_normalize_signature(),
  overwrite = TRUE
)
```

## Arguments

- project:

  Project directory. Defaults to the active project
  ([`np_project_root()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_project_root.md)).

- signature:

  The signature to record. Defaults to the installed normalizer's, which
  is the right value when the cache was just built.

- overwrite:

  Overwrite an existing `SIGNATURE.txt`? Defaults to `TRUE`: a stamp
  records the cache as it now is, so refusing to update it would leave a
  stale claim in place.

## Value

The path written, invisibly.

## Details

The normalized reference, the token-IDF table and the blocking index are
built once per reference vintage and reused by every run. If the
normalization rules move after the cache was built, the cache is stale
and a run over it is not reproducible against current code. The stamp
makes that detectable rather than silent.

The first line is the bare signature, so a reader that compares
`readLines(f)[1]` to
[`np_normalize_signature()`](https://nonprofit-open-data-collective.github.io/npnormalize/reference/np_normalize_signature.html)
keeps working — including against the hand-written single-line files
this function replaces. The commented lines below it carry the release,
the installed npnormalize version and the time of the stamp.

Pass `signature` explicitly when stamping a bundle that was *not* built
by the installed normalizer — recording an older bundle's real
provenance rather than overwriting it with the current value.

## See also

[`np_project_init()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_project_init.md)
creates the folder the stamp lives in;
[`np_project_status()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_project_status.md)
reports whether it is present.

## Examples

``` r
p <- file.path(tempdir(), "npp-stamp")
np_project_init(p, run_id = "demo", quiet = TRUE, use = FALSE)
np_signature_stamp(p)
cat(readLines(file.path(p, "00_bmf", "SIGNATURE.txt")), sep = "\n")
#> v1-5e901add4a04a5d6
#> # normalizer: v1-5e901add4a04a5d6 (npnormalize 0.1.8)
#> # installed:  npnormalize 0.1.9
#> # stamped:    2026-11-02 21:43:30
#> #
#> # The first line is the np_normalize_signature() fingerprint of the
#> # normalizer that built the cached normalized bundle this run points at.
#> # If np_normalize_signature() stops reporting it, the cache has drifted
#> # from the current normalization rules and must be rebuilt.
unlink(p, recursive = TRUE)
```
