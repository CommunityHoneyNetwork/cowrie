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
    local ipv6=${IPV6_ENABLE:-"false"}
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
        -i "${REPORTED_IP:-""}"

    local uid="$(cat ${COWRIE_JSON} | jq -r .identifier)"
    local secret="$(cat ${COWRIE_JSON} | jq -r .secret)"

    export COWRIE_output_hpfeeds3__debug="${DEBUG}"
    export COWRIE_output_hpfeeds3__server="${FEEDS_SERVER}"
    export COWRIE_output_hpfeeds3__port="${FEEDS_SERVER_PORT:-10000}"
    export COWRIE_output_hpfeeds3__identifier="${uid}"
    export COWRIE_output_hpfeeds3__secret="${secret}"
    export COWRIE_output_hpfeeds3__tags="${tags}"
    if [ ! -z "${REPORTED_IP}" ]
    then
      export COWRIE_output_hpfeeds3__reported_ip="${REPORTED_IP}"
    fi

    local default_endpoint="http://${FEEDS_SERVER}:8000"
    export COWRIE_output_s3__enabled="${S3_OUTPUT_ENABLED:-false}"
    export COWRIE_output_s3__access_key_id="${S3_ACCESS_KEY:-${uid}}"
    export COWRIE_output_s3__secret_access_key="${S3_SECRET_KEY:-${secret}}"
    export COWRIE_output_s3__region="${S3_REGION:-region}"
    export COWRIE_output_s3__bucket="${S3_BUCKET:-}"
    export COWRIE_output_s3__endpoint="${S3_ENDPOINT:-${default_endpoint}}"
    export COWRIE_output_s3__verify="${S3_VERIFY:-no}"


    if [[ ${ipv6} == "true" ]]
    then
      export COWRIE_ssh__listen_endpoints="tcp:${SSH_LISTEN_PORT:-2222}:interface=\:\:"
      export COWRIE_telnet__listen_endpoints="tcp:${TELNET_LISTEN_PORT:-2223}:interface=\:\:"
    else
      export COWRIE_ssh__listen_endpoints="tcp:${SSH_LISTEN_PORT:-2222}:interface=0.0.0.0"
      export COWRIE_telnet__listen_endpoints="tcp:${TELNET_LISTEN_PORT:-2223}:interface=0.0.0.0"
    fi
    # Write out custom cowrie config
    containedenv-config-writer.py \
      -p COWRIE_ \
      -f ini \
      -r /code/cowrie.reference.cfg \
      -o /opt/cowrie/etc/cowrie.cfg

    /opt/cowrie/bin/cowrie start --nodaemon
}

main "$@"
