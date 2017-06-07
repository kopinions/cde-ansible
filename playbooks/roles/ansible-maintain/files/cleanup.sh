#!/usr/bin/env bash

ME=`basename $0`;
LOCK="/tmp/${ME}.lock";

# create a file descriptor which value is 8
exec 8>${LOCK};

if flock -n -x 8; then
    docker ps -a -q -f 'status=exited' -f 'status=created' -f 'status=dead' | xargs -r docker rm
    docker images -q -f 'dangling=true' | xargs -r docker rmi
    docker volume ls -qf 'dangling=true' | xargs -r docker volume rm
else
    echo "Still cleaning";
fi

