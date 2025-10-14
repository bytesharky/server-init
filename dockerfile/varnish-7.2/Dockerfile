FROM varnish:7.2

USER root

# 确保 www-data 存在
RUN set -eux; \
    if getent passwd www-data >/dev/null; then \
        deluser www-data; \
    fi; \
    if getent group www-data >/dev/null; then \
        delgroup www-data; \
    fi; \
    addgroup --gid 33 --system www-data; \
    adduser --uid 33 --system --home /var/www  --ingroup www-data www-data; \
    usermod -aG varnish www-data; \
    chown -R www-data:www-data /var/lib/varnish; \
    chmod -R g+w /var/lib/varnish;

# 使用 www-data 启动 Varnish
USER www-data
