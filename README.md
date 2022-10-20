# Let's Encrypt NGINX Docker (lend)

`lend` is a collection of convenience scripts for SSL/TLS configuration.

## Local

> `lend.sh`

### Usage

```text
Usage:
    /bin/bash lend.sh -v <volume> <server_name> [<server_name> ...]

    -v <volume>, --volume-letsencrypt <volume>  /etc/letsencrypt volume name
    <server_name>                               Server names as defined in the server_name directive
                                                e.g. "example.test www.example.test"
```

### Example

```sh
% curl -fsSL https://raw.githubusercontent.com/joehehir/lend/master/lend.sh -o lend.sh
% /bin/bash lend.sh -v "letsencrypt" "example.test www.example.test"
[info]: /etc/hosts updated

# [inspect]
% docker run --rm -i -v letsencrypt:/etc/letsencrypt busybox find /etc/letsencrypt -type f
/etc/letsencrypt/options-ssl-nginx.conf
/etc/letsencrypt/ssl-dhparams.pem
/etc/letsencrypt/live/example.test/privkey.pem
/etc/letsencrypt/live/example.test/fullchain.pem

# [run]
% docker compose up --build
```
