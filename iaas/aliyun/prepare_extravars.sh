#!/usr/bin/env bash

if [[ ! -f infrastructure.json ]] ; then
    echo $'\033[0;31m'"No infrastructure.json found, please run the provision first" $'\033[0m'
    exit 1
fi

MASTER=$(cat infrastructure.json |jq -r '.master')
SLAVE=$(cat infrastructure.json |jq -r '.slave')

jq -n --argjson master "$MASTER" --argjson slave "$SLAVE" '{
    ansible_user: "ubuntu",
    ansible_ssh_user: "ubuntu",
    ansible_ssh_private_key_file: "",
    zookeeper_hosts: ($master|map(.private)|to_entries|map({address:.value, id:(.key+1)})),
    elasticsearch_endpoint: ($master|map(.private)|.[0]+":9200"),
    consul_servers: ($master|map(.private)),
    consul_bootstrap_expect: ($master|map(.private)|length),
    mesos_quorum: ((($master|length)/2 +1)|floor),
    elasticsearch_masters: ($master|map(.private)),
    java: "oracle-java8-installer",
    marathon_env_java_opts: "-Xmx256m",
    ipaddr: "{{ansible_eth0.ipv4.address}}",
    ceph_stable: "true",
    journal_collocation: "true",
    journal_size: 100,
    monitor_interface: "eth0",
    cluster_network: "172.31.0.0/16",
    public_network: "172.31.0.0/16",
    devices: ("/dev/vdb"|split(" ")),
    os_tuning_params: [{
      name: "kernel.pid_max",
      value: 4194303
    },
    {
      name: "fs.file-max",
      value: 26234859
    }],
    "control_hostname": ($slave[0].private)
}' > extravars.json
