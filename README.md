Synapse (matrix server) scripts for Anarchy Planet.

## Dependencies

[curl](https://curl.se/) for GET and POST to the synapse API.

[jq](https://stedolan.github.io/jq/) for JSON parsing.

psql utility, which is normally automatically installed with the
postgresql server.

[synapse-compress-state](https://github.com/matrix-org/rust-synapse-compress-state)
for compressing the synapse state tables.

## Installing

With this repository as your working directory, run `make` as root.

## Using the scripts

### synapse-purge-compress

The postgres database for the matrix synapse server grows big fast.
This script brings its size back down by purging old data and
compressing the state tables.

Run as the matrix-synapse user, for example:

    sudo -u matrix-synapse synapse-purge-compress

Run from cron:

    sudo -u matrix-synapse crontab -e

Add a line like so:

    0 2 1 * * /usr/local/bin/synapse-purge-compress

NOTE: the script is still very verbose, so you may want to run it
with chronic from [moreutils](https://www.putorius.net/moreutils.html).
