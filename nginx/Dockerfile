FROM nginx:1.23.1-alpine AS production

COPY ./nginx/. /etc/nginx/

RUN mkdir /etc/nginx/locations-enabled/ \
    && mkdir /etc/nginx/sites-enabled/ \
    && ln -s /etc/nginx/locations-available/*.conf /etc/nginx/locations-enabled/ \
    && ln -s /etc/nginx/sites-available/*.conf /etc/nginx/sites-enabled/ \
    && rm -f /etc/nginx/sites-enabled/default

COPY ./www/. /var/www/

EXPOSE 80 443

CMD ["nginx"]

FROM production AS development

ARG SITE_DEVELOPMENT="example.test" \
    SITE_PRODUCTION="example.com"

# nginx envsubst
RUN sed -i -E \
        -e "/^[[:space:]]*(server_name|ssl_certificate)/s/${SITE_PRODUCTION}/${SITE_DEVELOPMENT}/g" \
        -e "/^[[:space:]]*ssl_stapling/d" \
        "/etc/nginx/sites-available/${SITE_PRODUCTION}.conf"
