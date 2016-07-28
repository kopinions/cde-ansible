#!/usr/bin/env bash

if [[ ! -f infrastructure.json ]] ; then
    echo $'\033[0;31m'"No infrastructure.json found, please run the provision first" $'\033[0m'
    exit 1
fi

echo "[zookeeper]" > hosts
cat infrastructure.json |jq -r '.master|map(.public)[]' >> hosts
echo >> hosts
echo "[marathon]" >> hosts
cat infrastructure.json |jq -r '.master|map(.public)[]' >> hosts
echo >> hosts
echo "[consul-server]" >> hosts
cat infrastructure.json |jq -r '.master|map(.public)[]' >> hosts
echo >> hosts
echo "[mesos-master]" >> hosts
cat infrastructure.json |jq -r '.master|map(.public)[]' >> hosts
echo >> hosts
echo "[mons]" >> hosts
cat infrastructure.json |jq -r '.master|map(.public)[]' >> hosts
echo >> hosts
echo "[elasticsearch-master]" >> hosts
cat infrastructure.json |jq -r '.master|map(.public)[]' >> hosts
echo >> hosts
echo "[mesos-slave]" >> hosts
cat infrastructure.json |jq -r '.slave|map(.public)[]' >> hosts
echo >> hosts
echo "[osds]" >> hosts
cat infrastructure.json |jq -r '.slave|map(.public)[]' >> hosts
echo >> hosts
echo "[flocker-control]" >> hosts
cat infrastructure.json |jq -r '.slave[0]|.public' >> hosts
echo >> hosts
echo "[flocker-agent]" >> hosts
cat infrastructure.json |jq -r '.slave|map(.public)[]' >> hosts
echo >> hosts
echo "[elasticsearch-node]" >> hosts
cat infrastructure.json |jq -r '.slave|map(.public)[]' >> hosts