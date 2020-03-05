#!/bin/bash

trap "exit 130" SIGINT
trap "exit 137" SIGKILL
trap "exit 143" SIGTERM

set -o errexit
set -o nounset
set -o pipefail

COWRIE_JSON='/etc/cowrie/cowrie.json'

main () {

    DEBUG=${DEBUG:-false}
    if [[ ${DEBUG} == "true" ]]
    then
      set -o xtrace
    fi

    local ssh_port=${SSH_LISTEN_PORT:-2222}
    local telnet_port=${TELNET_LISTEN_PORT:-2223}
    local tags=${TAGS:-}

    if [[ -z ${DEPLOY_KEY} ]]
    then
      echo "[CRIT] - No deploy key found"
      exit 1
    fi

    # Create some required directories
    mkdir -p /data/logs
    mkdir -p /data/state/{tty,downloads}

    # Register this host with CHN if needed
    chn-register.py \
        -p cowrie \
        -d "${DEPLOY_KEY}" \
        -u "${CHN_SERVER}" -k \
        -o "${COWRIE_JSON}" \
        -i "${IP_ADDRESS}"

    local uid="$(cat ${COWRIE_JSON} | jq -r .identifier)"
    local secret="$(cat ${COWRIE_JSON} | jq -r .secret)"

    export COWRIE_output_hpfeeds3__debug="${DEBUG}"
    export COWRIE_output_hpfeeds3__server="${FEEDS_SERVER}"
    export COWRIE_output_hpfeeds3__port="${FEEDS_SERVER_PORT:-10000}"
    export COWRIE_output_hpfeeds3__identifier="${uid}"
    export COWRIE_output_hpfeeds3__secret="${secret}"

    export COWRIE_ssh__listen_endpoints="tcp:${SSH_LISTEN_PORT:-2222}:interface=0.0.0.0"
    export COWRIE_telnet__listen_endpoints="tcp:${TELNET_LISTEN_PORT:-2223}:interface=0.0.0.0"

    # Write out custom cowrie config
    containedenv-config-writer.py \
      -p COWRIE_ \
      -f ini \
      -r /code/cowrie.reference.cfg \
      -o /opt/cowrie/etc/cowrie.cfg

    /opt/cowrie/bin/cowrie start --nodaemon
}

main "$@"
