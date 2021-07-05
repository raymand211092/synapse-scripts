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

The scripts can only be run interactively, as they prompt for certain
passwords and parameters. They do not parse any arguments.
