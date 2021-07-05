#!/bin/sh

# don't bother compressing unless we will save this much:
min_compression_percent=20

read -p "synapse admin API access token: " token
read -p "postgres synapse user password: " db_password

get_synapse_version () {
    curl --silent --ssl -H "Authorization: Bearer $token" \
        "localhost:8008/_synapse/admin/v1/server_version"
}

get_all_rooms () {
    curl --silent -H "Authorization: Bearer $token" \
        "localhost:8008/_synapse/admin/v1/rooms" \
        | jq '.rooms[].room_id' \
        | sed 's/"//g'
}

compress_state () {
    for room_id ; do
        sqlf="$HOME/$(echo $room_id | tr -c -d '[:alpha:]').sql"
        repl=$(synapse-compress-state -t -o $sqlf -p \
            "host=localhost user=synapse password=${db_password} dbname=synapse" \
            -r "$room_id" | sed -n '/%/s/.*(\([0-9]*\).[0-9]*%).*/\1/p')

        if [ "$repl" -le "$((100 - $min_compression_percent))" ]; then
            echo "compressing room" $room_id "..."
            psql -q -U 'synapse' -f $sqlf 'synapse'
        fi
        rm $sqlf
    done
}

compress_state $(get_all_rooms)
