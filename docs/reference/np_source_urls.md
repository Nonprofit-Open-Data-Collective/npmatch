# Known npmatch data sources

The pinned **archive** snapshots (the exact vintages used to build the
shipped crosswalk, hosted on the NCCS S3 bucket) plus the **source**
landing pages for pulling fresh files. Archive files let documentation
reproduce outputs exactly; source pages let you check for newer data.

## Usage

``` r
np_source_urls()
```

## Value

A data frame with columns `key`, `kind` (`"archive"`/`"source"`), `url`,
and `note`.
