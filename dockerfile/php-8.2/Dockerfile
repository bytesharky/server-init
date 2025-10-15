# ===============================
# 第一阶段：编译扩展
# ===============================
FROM php:8.2-fpm-alpine AS builder

# 安装编译工具和依赖
RUN apk add --no-cache \
        autoconf \
        gcc \
        g++ \
        make \
        libc-dev \
        libpng-dev \
        libjpeg-turbo-dev \
        libwebp-dev \
        freetype-dev \
        libzip-dev \
        oniguruma-dev \
        icu-dev \
        bash \
        unzip \
        curl

# 配置 GD 编译选项
RUN docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
        --with-webp

# 编译 PHP 内置扩展
RUN docker-php-ext-install -j$(nproc) \
        mysqli \
        pdo_mysql \
        gd \
        intl \
        zip

# 安装 PECL 扩展
RUN pecl install redis \
    && docker-php-ext-enable redis

# ===============================
# 第二阶段：生成最小运行镜像
# ===============================
FROM php:8.2-fpm-alpine

# 复制编译好的扩展和 PHP 配置
COPY --from=builder /usr/local/lib/php/extensions /usr/local/lib/php/extensions
COPY --from=builder /usr/local/etc/php-fpm.d /usr/local/etc/php-fpm.d
COPY --from=builder /usr/local/etc/php /usr/local/etc/php

# 确保 www-data 存在
RUN set -eux; \
    if getent passwd www-data >/dev/null; then \
        deluser www-data; \
    fi; \
    if getent group www-data >/dev/null; then \
        delgroup www-data; \
    fi; \
    addgroup -g 33 -S www-data; \
    adduser -u 33 -S -D -H -s /sbin/nologin -G www-data www-data

# 安装运行时依赖
RUN apk add --no-cache \
        libpng \
        libjpeg-turbo \
        libwebp \
        freetype \
        oniguruma \
        libzip \
        icu-libs \
        unzip \
        curl \
        && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
        && composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/

# 设置工作目录
WORKDIR /var/websites/

# 默认启动命令
CMD ["php-fpm"]
