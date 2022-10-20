#!/bin/bash
set -eu

# Let's Encrypt NGINX Docker (lend)
# https://github.com/joehehir/lend/blob/master/live/ubuntu-lts/lend-renew.cron.sh
# v1.0.0

readonly SCRIPT_NAME="lend-renew.cron"

usage() {
    cat << EOF >&2
Usage:
    /bin/bash ${SCRIPT_NAME}.sh --compose-file <file> --cron-mailto <email> --cron-schedule-expression <exp> --service-certbot <service> --service-nginx <service> <server_name> [<server_name> ...]

    --compose-file <file>               Docker Compose file
    --cron-mailto <email>               crontab MAILTO environment variable
    --cron-schedule-expression <exp>    cron schedule expression
    --service-certbot <service>         Certbot service name as defined in --compose-file
    --service-nginx <service>           NGINX service name as defined in --compose-file
    <server_name>                       Server names as defined in the server_name directive
                                        e.g. "example.com www.example.com"

EOF

}

mk_script() {
    local -r output="${1}"
    local renew_commands=""

    local domains
    local domain_args
    local entrypoint

    for domains in "${server_names[@]}"
    do
        domain_args="-d ${domains[*]// / -d }"
        entrypoint="certbot certonly --webroot -w /var/www/certbot --noninteractive ${domain_args}"

        renew_commands="${renew_commands}docker compose -f \"${compose_file}\" run --rm --entrypoint \"${entrypoint}\" ${service_certbot}\n"
    done

    renew_commands="$(printf "%b\n" "${renew_commands}")"

cat << EOF > "${output}"
#!/bin/bash

${renew_commands}
docker compose -f "${compose_file}" exec ${service_nginx} /bin/sh -c "nginx -s reload"

EOF

}

main() {
    local -ir EXPECTED_STATE=63

    local cron_mailto
    local cron_schedule_expression
    local compose_file
    local service_certbot
    local service_nginx
    local -a server_names=()
    local -i state=0

    while test $# -gt 0
    do
        case "${1}" in
            --help)
                usage
                exit
                ;;
            --cron-mailto)
                state=$((state | 1 << 0))
                shift
                cron_mailto="${1}"
                shift
                ;;
            --cron-schedule-expression)
                state=$((state | 1 << 1))
                shift
                cron_schedule_expression="${1}"
                shift
                ;;
            --compose-file)
                state=$((state | 1 << 2))
                shift
                compose_file="${1}"
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
            *)
                state=$((state | 1 << 5))
                server_names+=("${1}")
                shift
                ;;
        esac
    done

    (( state != EXPECTED_STATE )) && {
        usage
        exit 1
    }

    local -r cron_mailto
    local -r cron_schedule_expression
    local -r compose_file
    local -r service_certbot
    local -r service_nginx
    local -r server_names

    sudo apt-get -y update \
        && sudo apt-get -y install cron \
        && sudo systemctl enable cron

    mk_script "/tmp/${SCRIPT_NAME}" \
        && sudo mv "/tmp/${SCRIPT_NAME}" "/usr/local/bin/${SCRIPT_NAME}" \
        && chmod +x "/usr/local/bin/${SCRIPT_NAME}"

cat << EOF > "/tmp/${SCRIPT_NAME}"
$(
    crontab -l 2> /dev/null \
    | sed "/# <${SCRIPT_NAME//./\\.}>/,/# <\/${SCRIPT_NAME//./\\.}>/d"
)
# <${SCRIPT_NAME}>
MAILTO="${cron_mailto}"
${cron_schedule_expression} /bin/bash /usr/local/bin/${SCRIPT_NAME}
# </${SCRIPT_NAME}>

EOF
# !important: \n\nEOF\n

    crontab "/tmp/${SCRIPT_NAME}"
    rm "/tmp/${SCRIPT_NAME}"
}
main "${@}"
