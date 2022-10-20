#!/bin/bash
set -eu

# Let's Encrypt NGINX Docker (lend)
# https://github.com/joehehir/lend/blob/master/live/ubuntu-lts/lend-request.sh
# v1.0.0

readonly SCRIPT_NAME="lend-request"

usage() {
    cat << EOF >&2
Usage:
    /bin/bash ${SCRIPT_NAME}.sh --compose-file <file> --letsencrypt-registration-email <email> --rsa-key-size <int> --service-certbot <service> --service-nginx <service> --volume-certbot <volume> --volume-letsencrypt <volume> <server_name> [<server_name> ...]

    --compose-file <file>                       Docker Compose file
    --letsencrypt-registration-email <email>    Email used for Let's Encrypt registration and recovery contact
    --rsa-key-size <int>                        Size of the RSA key
    --service-certbot <service>                 Certbot service name as defined in --compose-file
    --service-nginx <service>                   NGINX service name as defined in --compose-file
    --volume-certbot <volume>                   /var/www/certbot volume name as defined in --compose-file
    --volume-letsencrypt <volume>               /etc/letsencrypt volume name as defined in --compose-file
    <server_name>                               Server names as defined in the server_name directive
                                                e.g. "example.com www.example.com"

EOF

}

init() {
    local -r EPHEMERAL_CONTAINER="ephemeral_${SCRIPT_NAME}"
    local -r EPHEMERAL_LETSENCRYPT_DIR="/tmp/${SCRIPT_NAME}"

    local domains
    local site

    for domains in "${server_names[@]}"
    do
        site="${domains%% *}"
        mkdir -p "${EPHEMERAL_LETSENCRYPT_DIR}/live/${site}"
    done

    curl --silent --show-error --output "${EPHEMERAL_LETSENCRYPT_DIR}/options-ssl-nginx.conf" \
        https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf
    curl --silent --show-error --output "${EPHEMERAL_LETSENCRYPT_DIR}/ssl-dhparams.pem" \
        https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem

    docker container create \
        --name "${EPHEMERAL_CONTAINER}" \
        -v "${volume_certbot}:/var/www/certbot/" \
        -v "${volume_letsencrypt}:/etc/letsencrypt/" \
        hello-world \
        && docker cp "${EPHEMERAL_LETSENCRYPT_DIR}/." "${EPHEMERAL_CONTAINER}:/etc/letsencrypt/"

    docker rm "${EPHEMERAL_CONTAINER}"
    rm -rf "${EPHEMERAL_LETSENCRYPT_DIR}"

    for domains in "${server_names[@]}"
    do
        site="${domains%% *}"

        docker compose -f "${compose_file}" run --rm --entrypoint "\
            openssl req \
                -x509 \
                -days 1 \
                -nodes \
                -newkey rsa:${rsa_key_size} \
                -out \"/etc/letsencrypt/live/${site}/fullchain.pem\" \
                -keyout \"/etc/letsencrypt/live/${site}/privkey.pem\" \
                -subj \"/CN=localhost\"" \
            "${service_certbot}"
    done
}

request() {
    local domains
    local site
    local domain_args

    for domains in "${server_names[@]}"
    do
        site="${domains%% *}"

        docker compose -f "${compose_file}" run --rm --entrypoint "\
            rm -rf \"/etc/letsencrypt/live/${site}\"
            rm -rf \"/etc/letsencrypt/archive/${site}\"
            rm -rf \"/etc/letsencrypt/renewal/${site}.conf\"" \
            "${service_certbot}"

        domain_args="-d ${domains[*]// / -d }"

        docker compose -f "${compose_file}" run --rm --entrypoint "\
            certbot certonly \
                --webroot -w /var/www/certbot \
                ${domain_args} \
                --rsa-key-size ${rsa_key_size} \
                --force-renewal \
                --email ${letsencrypt_registration_email} \
                --non-interactive \
                --agree-tos" \
            "${service_certbot}"
    done
}

main() {
    local -ir EXPECTED_STATE=255

    local compose_file
    local letsencrypt_registration_email
    local rsa_key_size
    local service_certbot
    local service_nginx
    local volume_certbot
    local volume_letsencrypt
    local -a server_names=()
    local -i state=0

    while test $# -gt 0
    do
        case "${1}" in
            --help)
                usage
                exit
                ;;
            --compose-file)
                state=$((state | 1 << 0))
                shift
                compose_file="${1}"
                shift
                ;;
            --letsencrypt-registration-email)
                state=$((state | 1 << 1))
                shift
                letsencrypt_registration_email="${1}"
                shift
                ;;
            --rsa-key-size)
                state=$((state | 1 << 2))
                shift
                rsa_key_size="${1}"
                shift
                ;;
            --service-certbot)
                state=$((state | 1 << 3))
                shift
                service_certbot="${1}"
                shift
                ;;
            --service-nginx)
                state=$((state | 1 << 4))
                shift
                service_nginx="${1}"
                shift
                ;;
            --volume-certbot)
                state=$((state | 1 << 5))
                shift
                volume_certbot="${1}"
                shift
                ;;
            --volume-letsencrypt)
                state=$((state | 1 << 6))
                shift
                volume_letsencrypt="${1}"
                shift
                ;;
            *)
                state=$((state | 1 << 7))
                server_names+=("${1}")
                shift
                ;;
        esac
    done

    (( state != EXPECTED_STATE )) && {
        usage
        exit 1
    }

    local -r compose_file
    local -r letsencrypt_registration_email
    local -r rsa_key_size
    local -r service_certbot
    local -r service_nginx
    local -r volume_certbot
    local -r volume_letsencrypt
    local -r server_names

    init
    docker compose -f "${compose_file}" up --force-recreate -d "${service_nginx}"
    request
    docker compose -f "${compose_file}" down
}
main "${@}"
