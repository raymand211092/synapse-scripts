#!/bin/sh

# guide: https://levans.fr/shrink-synapse-database.html
# doc: https://matrix-org.github.io/synapse/develop/admin_api/purge_history_api.html

synapse_log='/var/log/matrix-synapse/homeserver.log'

read -p "synapse admin API access_token: " token
read -p "history to keep (date range with no spaces, eg 1month, 1day): " range

# timestamps are in milliseconds since the epoch
ts_history="$(date -d-${range} +%s)000"
ts_media="$(date -d-1month +%s)000"

get_obsolete_rooms () {
    tmpf=$(mktemp)
    curl --silent -H "Authorization: Bearer $token" \
        "localhost:8008/_synapse/admin/v1/rooms" \
        | jq '.rooms[] | select(.joined_local_members == 0) | .room_id' \
        | sed 's/"//g'
}

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

purge_obsolete_rooms () {
    for room_id in $(get_obsolete_rooms); do
        curl --silent --ssl -X POST --header "Content-Type: application/json" \
            --header "Authorization: Bearer $token" \
            -d "{ \"room_id\": \"$room_id\" }" \
            "localhost:8008/_synapse/admin/v1/purge_room" \
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
            -d "{ \"delete_local_events\": false, \"purge_up_to_ts\": $ts_history }" \
            "localhost:8008/_synapse/admin/v1/purge_history/${room_id}")
        echo $json | jq
        if echo $json | grep -q 'purge_id'; then
            echo "waiting for purge to complete..."
            tail -n 0 -f $synapse_log \
                | sed '/\[purge\] complete/q' > /dev/null
            echo "purge completed."
        fi
    done
    echo "it is recommended to run VACUUM FULL on the database now"
    echo "(note: VACUUM FULL requires up to 50% of the disk be available)"
}

purge_media_cache () {
    curl --silent -X POST --ssl \
        --header "Authorization: Bearer $token" -d '' \
        "localhost:8008/_synapse/admin/v1/purge_media_cache?before_ts=${ts_media}" \
        | jq
}

purge_obsolete_rooms
purge_history $(get_all_rooms)
purge_media_cache
