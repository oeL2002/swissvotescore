# swissvotescore

This repository factors out the functions that transform Swiss vote data from
[swissdd](https://github.com/politanch/swissdd). swissdd also does web fetching and
plotting; I only need the transform for a reproducible pipeline.

swissdd resolves a vote date to a URL through the opendata.swiss CKAN API and downloads
it before parsing. That makes results depend on what the API serves at run time, which
is fine for following a vote Sunday live and wrong for a pipeline that has to reproduce
from an archived copy of the data. This package keeps the parsing and drops the
fetching: you supply the JSON, it hands back a data frame. No network access.

## Install

With Nix, as a flake input:

```nix
inputs.swissvotescore.url = "github:oeL2002/swissvotescore";
# then, built against your own nixpkgs:
#   inputs.swissvotescore.inputs.nixpkgs.follows = "nixpkgs";
#   rWrapper.override { packages = [ inputs.swissvotescore.packages.${system}.default ]; }
```

An `overlays.default` is exported too, if you would rather refer to it as
`rPackages.swissvotescore`.

Otherwise:

```r
remotes::install_github("oeL2002/swissvotescore")
```

## Use

```r
library(swissvotescore)

# federal votes
d <- swiss_json_to_dfr("klimaschutz_2023.json",
                       votedate = "2023-06-18",
                       geolevel = "municipality")

# cantonal votes
k <- canton_json_to_dfr("kantonale_2020-02-09.json", votedate = "2020-02-09")
```

Both functions take either a path to a JSON file or JSON you have already parsed with
`jsonlite::fromJSON()`, so the caller decides where the bytes come from. `votedate` is
required — it cannot be inferred from a local file the way it could from a URL.

`geolevel` accepts `"national"`, `"canton"`, `"district"`, `"municipality"` and
`"zh_counting_districts"`. That last one substitutes Zürich's and Winterthur's counting
districts for the two municipalities, which is how those cities report.

## Where the data comes from

The Federal Statistical Office publishes one JSON per vote day, via the opendata.swiss
package `echtzeitdaten-am-abstimmungstag-zu-eidgenoessischen-abstimmungsvorlagen`
(and its `-kantonalen-` sibling). Each resource's `download_url` is a stable
`https://dam-api.bfs.admin.ch/hub/api/dam/assets/<id>/master`. Download it however you
like; archive it; pass the file here.

Municipality-level results exist only in this JSON — the "detaillierte Ergebnisse"
spreadsheets are canton-level, and the dataset publishes no CSV.

## Differences from swissdd

|                                            | swissdd                       | here                     |
| ------------------------------------------ | ----------------------------- | ------------------------ |
| input                                      | URL, fetched with `httr::GET` | file path or parsed JSON |
| `votedate`                                 | optional, resolved from CKAN  | required                 |
| fetching, plotting, geodata, Swissvotes DB | yes                           | no — use swissdd         |

Only `swiss_json_to_dfr()` and `canton_json_to_dfr()` are kept. For everything else,
including live vote-Sunday data, `get_geodata()` and the Swissvotes database, use
swissdd itself.

Verified identical: run against the three federal vote days 2017-05-21, 2021-06-13 and
2023-06-18, this package returns the same 19,051 rows and 17 columns as upstream
swissdd 1.1.6 fetching the same files over the network — no differing keys, no
differing values.

## Credit and licence

Written by Thomas Lo Russo and Thomas Willi as part of
[swissdd](https://github.com/politanch/swissdd); the transform code here is theirs.
This package removes the fetching layer and keeps nothing else.

GPL (>= 2), as swissdd is.
