# Live

## New request

> `lend-request.sh`

### Usage

```text
Usage:
    /bin/bash lend-request.sh --compose-file <file> --letsencrypt-registration-email <email> --rsa-key-size <int> --service-certbot <service> --service-nginx <service> --volume-certbot <volume> --volume-letsencrypt <volume> <server_name> [<server_name> ...]

    --compose-file <file>                       Docker Compose file
    --letsencrypt-registration-email <email>    Email used for Let's Encrypt registration and recovery contact
    --rsa-key-size <int>                        Size of the RSA key
    --service-certbot <service>                 Certbot service name as defined in --compose-file
    --service-nginx <service>                   NGINX service name as defined in --compose-file
    --volume-certbot <volume>                   /var/www/certbot volume name as defined in --compose-file
    --volume-letsencrypt <volume>               /etc/letsencrypt volume name as defined in --compose-file
    <server_name>                               Server names as defined in the server_name directive
                                                e.g. "example.com www.example.com"
```

### Example

```sh
% curl -fsSL https://raw.githubusercontent.com/joehehir/lend/master/live/ubuntu-lts/lend-request.sh -o lend-request.sh
% /bin/bash lend-request.sh \
    --compose-file "/absolute/path/to/docker-compose.yml" \
    --letsencrypt-registration-email "admin@example.com" \
    --rsa-key-size 4096 \
    --service-certbot "certbot" \
    --service-nginx "nginx" \
    --volume-certbot "certbot" \
    --volume-letsencrypt "letsencrypt" \
    "example.com www.example.com"
```

## Automatic renewal

> `lend-renew.cron.sh`

### Usage

```text
Usage:
    /bin/bash lend-renew.cron.sh --compose-file <file> --cron-mailto <email> --cron-schedule-expression <exp> --service-certbot <service> --service-nginx <service> <server_name> [<server_name> ...]

    --compose-file <file>               Docker Compose file
    --cron-mailto <email>               crontab MAILTO environment variable
    --cron-schedule-expression <exp>    cron schedule expression
    --service-certbot <service>         Certbot service name as defined in --compose-file
    --service-nginx <service>           NGINX service name as defined in --compose-file
    <server_name>                       Server names as defined in the server_name directive
                                        e.g. "example.com www.example.com"
```

### Example

```sh
% curl -fsSL https://raw.githubusercontent.com/joehehir/lend/master/live/ubuntu-lts/lend-renew.cron.sh -o lend-renew.cron.sh
% /bin/bash lend-renew.cron.sh \
    --compose-file "/absolute/path/to/docker-compose.yml" \
    --cron-mailto "" \
    --cron-schedule-expression "00 12 * * 3" \
    --service-certbot "certbot" \
    --service-nginx "nginx" \
    "example.com www.example.com"
```
