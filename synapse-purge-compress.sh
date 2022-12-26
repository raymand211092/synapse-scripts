#!/bin/sh

set -e

# guide: https://levans.fr/shrink-synapse-database.html
# doc: https://matrix-org.github.io/synapse/develop/admin_api/purge_history_api.html

host='localhost'
port='8008'
synapse_log='/var/log/matrix-synapse/homeserver.log'
db_conf_file='/etc/matrix-synapse/conf.d/database.yaml'
rooms_query_limit=6666
room_history_range="2months"
media_range="1month"

debug=0

# don't bother compressing unless we will save this much:
min_compression_percent=15

debug () {
    if [ "$debug" = 1 ]; then
        echo $* 1>&2
    fi
}
get_obsolete_rooms () {
    curl --silent -H "Authorization: Bearer $token" \
        "${host}:${port}/_synapse/admin/v1/rooms" \
        | jq '.rooms[] | select(.joined_local_members == 0) | .room_id' \
        | sed 's/"//g'
}

get_synapse_version () {
    curl --silent --ssl -H "Authorization: Bearer $token" \
        "${host}:${port}/_synapse/admin/v1/server_version"
}

get_all_rooms () {
    curl --silent -H "Authorization: Bearer $token" \
        "${host}:${port}/_synapse/admin/v1/rooms?limit=${rooms_query_limit}" \
        | jq '.rooms[].room_id' \
        | sed 's/"//g'
}

purge_obsolete_rooms () {
    for room_id in $(get_obsolete_rooms); do
        curl --silent --ssl -X POST --header "Content-Type: application/json" \
            --header "Authorization: Bearer $token" \
            -d "{ \"room_id\": \"$room_id\" }" \
            "${host}:${port}/_synapse/admin/v1/purge_room" \
            | jq
    done
}

purge_history () {
    # note: to delete local events as well, do:
    # -d "{ \"delete_local_events\": true, ... }"
    for room_id ; do
        json=$(curl --silent --ssl -X POST \
            --header "Content-Type: application/json" \
            --header "Authorization: Bearer $token" \
            -d "{ \"delete_local_events\": false, \"purge_up_to_ts\": $room_history_range_ts }" \
            "${host}:${port}/_synapse/admin/v1/purge_history/${room_id}")

        if echo $json | grep -q 'purge_id'; then
            debug "waiting for purge to complete..."
            tail -n 0 -f $synapse_log \
                | sed '/\[purge\] complete/q' > /dev/null
            debug "purge completed."
        fi
    done
}

purge_media_cache () {
    curl --silent -X POST --ssl \
        --header "Authorization: Bearer $token" -d '' \
        "${host}:${port}/_synapse/admin/v1/purge_media_cache?before_ts=${media_range_ts}" \
        | jq
}

compress_state () {
    umask 077
    for room_id ; do
        sqlf="/tmp/$(echo $room_id | tr -c -d '[:alpha:]').sql"
        repl=$(synapse-compress-state -t -o $sqlf -p \
            "host=${host} user=synapse password=${db_password} dbname=${db_name}" \
            -r "$room_id" | sed -n '/%/s/.*(\([0-9]*\).[0-9]*%).*/\1/p')

        if [ "$repl" -le "$((100 - $min_compression_percent))" ]; then
            debug "compressing room" $room_id "..."
            psql -q -U 'synapse' -f $sqlf 'synapse'
        fi
        rm $sqlf
    done
}
main () {
    echo "Purging obsolete rooms (rooms with no local members)"
    purge_obsolete_rooms
    echo "Purging room history older than ${room_history_range}"
    purge_history $(get_all_rooms)
    echo "Purging media cache older than ${media_range}"
    purge_media_cache
    echo "Compressing room state"
    compress_state $(get_all_rooms)
    echo "Reindexing and vacuuming the database"
    psql -q -c "REINDEX DATABASE synapse;" -c "VACUUM FULL;" -d synapse -U synapse
}

if test -r /etc/matrix-synapse/access_token ; then
    token="$(cat /etc/matrix-synapse/access_token)"
else
    # TODO: if standard output is not a tty, exit with failure
    read -p "synapse admin API access_token: " token
fi

if test -r $db_conf_file; then
    db_password="$(grep '^\s*password: ' $db_conf_file | awk '{print $2}')"
    db_name="$(grep '^\s*database: ' $db_conf_file | awk '{print $2}')"
else
    # TODO: if standard output is not a tty, exit with failure
    read -p "synapse database name: " db_name
    read -p "synapse database password: " db_password
fi

# synapse wants timestamps in milliseconds since the epoch
room_history_range_ts="$(date -d-${room_history_range} +%s)000"
media_range_ts="$(date -d-${media_range} +%s)000"

main
