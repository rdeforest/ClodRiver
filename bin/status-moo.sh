#!/bin/bash

(   sleep 1
    echo quit
) | (
    loginBanner=$(telnet localhost 7777)
)

telnetExit=$?

if [ 0 -lt $telnetExit ]; then
    cat <<EOF
There was an error trying to connect to the MOO.
If it's running, it's not healthy.
EOF
    exit $telnetExit
fi

if echo "$loginBanner" | grep -q "Welcome to JHcore"; then
    grepExit=$?
    cat <<EOF
Something responded on port 7777, but it didn't look like our MOO.
EOF
    exit $grepExit
fi

echo "No problems with the MOO, it seems."
