<div id="main" class="col-md-9" role="main">

# Known npmatch data sources

<div class="ref-description section level2">

The pinned **archive** snapshots (the exact vintages used to build the
shipped crosswalk, hosted on the NCCS S3 bucket) plus the **source**
landing pages for pulling fresh files. Archive files let documentation
reproduce outputs exactly; source pages let you check for newer data.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_source_urls()
```

</div>

</div>

<div class="section level2">

## Value

A data frame with columns `key`, `kind` (`"archive"`/`"source"`), `url`,
and `note`.

</div>

</div>
