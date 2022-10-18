#!/bin/bash
set -eu

# Let's Encrypt NGINX Docker (lend)
# https://github.com/joehehir/lend/lend.sh
# v1.0.0

readonly SCRIPT_NAME="lend"
readonly EPHEMERAL_CONTAINER="ephemeral_${SCRIPT_NAME}"
readonly EPHEMERAL_LETSENCRYPT_DIR="./.${SCRIPT_NAME}.bak"

usage() {
    cat << EOF >&2
Usage:
    ./${SCRIPT_NAME}.sh -v <volume> <server_name> [<server_name> ...]

    -v <volume>, --volume-letsencrypt <volume>  /etc/letsencrypt volume name
    <server_name>                               Server names as defined in the server_name directive
                                                e.g. "example.test www.example.test"

EOF

}

rm_artifacts() {
    docker rm "${EPHEMERAL_CONTAINER}" > /dev/null
    rm -rf "${EPHEMERAL_LETSENCRYPT_DIR}"
}

main() {
    trap rm_artifacts EXIT

    local -ir EXPECTED_STATE=3
    local -ar LOCAL_DEPENDENCIES=(
        "curl"
        "docker"
        "mkcert"
    )

    local volume_letsencrypt
    local -a server_names=()
    local -i state=0

    local dep
    local domains
    local site
    local dir
    local mkcert_err
    local mkcert_exitcode

    while test $# -gt 0
    do
        case "${1}" in
            --help)
                usage
                exit
                ;;
            -v|--volume-letsencrypt)
                state=$((state | 1 << 0))
                shift
                volume_letsencrypt="${1}"
                shift
                ;;
            *)
                state=$((state | 1 << 1))
                server_names+=("${1}")
                shift
                ;;
        esac
    done

    (( state != EXPECTED_STATE )) && {
        usage
        exit 1
    }

    local -r volume_letsencrypt
    local -r server_names

    for dep in "${LOCAL_DEPENDENCIES[@]}"
    do
        command -v "${dep}" &> /dev/null \
            || {
                printf "\"%s\" is required\n" "${dep}" >&2
                exit 1
            }
    done

    docker container create \
        --name "${EPHEMERAL_CONTAINER}" \
        -v "${volume_letsencrypt}:/etc/letsencrypt/" \
        hello-world \
        > /dev/null

    # shellcheck disable=SC2015
    [ -f /etc/hosts ] \
        && sudo -- sh -c -e "grep -qxF \"127.0.0.1 ${server_names[*]}\" /etc/hosts \
            || printf \"%s\n\" \"127.0.0.1 ${server_names[*]}\" >> /etc/hosts" \
        && printf "[info]: %s\n" "/etc/hosts updated" \
        || printf "[info]: %s\n" "/etc/hosts not updated" >&2

    for domains in "${server_names[@]}"
    do
        site="${domains%% *}"
        dir="${EPHEMERAL_LETSENCRYPT_DIR}/live/${site}"

        mkdir -p "${dir}"

        # shellcheck disable=SC2086
        mkcert_err="$(
            mkcert \
                -cert-file "${dir}/fullchain.pem" \
                -key-file "${dir}/privkey.pem" \
                $domains localhost 127.0.0.1 ::1 \
                2>&1
        )"
        mkcert_exitcode=$?
        [ $mkcert_exitcode -eq 0 ] \
            || {
                printf "%s\n" "${mkcert_err}" >&2
                exit 1
            }
    done

    curl --silent --show-error --output "${EPHEMERAL_LETSENCRYPT_DIR}/options-ssl-nginx.conf" \
        https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf
    curl --silent --show-error --output "${EPHEMERAL_LETSENCRYPT_DIR}/ssl-dhparams.pem" \
        https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem

    docker cp "${EPHEMERAL_LETSENCRYPT_DIR}/." "${EPHEMERAL_CONTAINER}:/etc/letsencrypt/"
}
main "${@}"
