FROM php:8.4-cli-bookworm as builder

WORKDIR /var/www/html

ARG TARGETARCH

# use TLSv1.0
RUN set -eux; \
   sed -i '/\[openssl_init\]/a ssl_conf = ssl_configuration' /etc/ssl/openssl.cnf; \
   echo "\n[ssl_configuration]" >> /etc/ssl/openssl.cnf; \
   echo "system_default = tls_system_default" >> /etc/ssl/openssl.cnf; \
   echo "\n[tls_system_default]" >> /etc/ssl/openssl.cnf; \
   echo "MinProtocol = TLSv1" >> /etc/ssl/openssl.cnf; \
   echo "CipherString = DEFAULT@SECLEVEL=0" >> /etc/ssl/openssl.cnf;

COPY uwsgi_profile.ini /usr/src/wpj.ini

# UWSGI
RUN set -eux; \
   savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		python3 \
		libargon2-dev \
      libcurl4-openssl-dev \
      libedit-dev \
      libsodium-dev \
      libsqlite3-dev \
      libssl-dev \
      libxml2-dev \
      zlib1g-dev \
      libpcre2-dev \
      libreadline-dev \
      libonig-dev \
    ;\
   export UWSGI_VERSION=2.0.30; \
   cd /usr/src; \
   curl -fsSL -o uwsgi.tar.gz https://github.com/unbit/uwsgi/archive/refs/tags/${UWSGI_VERSION}.tar.gz; \
   tar -xvzf uwsgi.tar.gz; \
   cd uwsgi-${UWSGI_VERSION}; \
   mv /usr/src/wpj.ini buildconf/wpj.ini; \
   # uwsgi tries to find libphp8
   ln -s libphp.so /usr/local/lib/libphp8.so; \
   # Remove '-pie' from ldflags
   sed -i "s/p_ldflags.remove('-Wl,--no-undefined')/p_ldflags.remove('-pie')/" uwsgiconfig.py; \
   UWSGICONFIG_PHPDIR=/usr/local python3 uwsgiconfig.py --build wpj; \
   mkdir /usr/local/uwsgi; \
   mv uwsgi *_plugin.so /usr/local/uwsgi; \
   rm -rf /usr/src/uwsgi-${UWSGI_VERSION}; \
   cd /usr/src; \
   # UWSGI end
   \
   apt-mark auto '.*' > /dev/null; \
   apt-mark manual $savedAptMark > /dev/null; \
   apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

RUN apt-get update \
   # Core PHP modules \
   && apt install -y --no-install-recommends libicu-dev libxml2-dev wget libjpeg62-turbo-dev libwebp-dev libbz2-dev zlib1g-dev libc-client-dev libmagickwand-dev libxslt-dev libzip-dev mariadb-client libonig-dev \
   && docker-php-ext-configure gd --with-jpeg=/usr --with-webp=/usr \
   && docker-php-ext-configure ftp --with-ftp-ssl  \
   && docker-php-ext-install pdo_mysql intl mbstring soap bz2 zip bcmath gd xsl calendar opcache gettext sockets ftp \
   # PECL
   && apt install -y --no-install-recommends libmemcached-dev librabbitmq-dev librdkafka-dev \
   && pecl install memcached apcu amqp igbinary rdkafka \
   && pecl install --configureoptions 'enable-redis-igbinary="yes"' redis \
   && docker-php-ext-enable igbinary memcached apcu amqp sockets redis \
   # Additional apps
   && apt-get update && apt-get install -y --no-install-recommends nano procps iputils-ping ghostscript less unzip python3-pip \
   # Install xlsx-streaming python library
   && pip install --break-system-packages xlsx-streaming json-stream

RUN cd /tmp && \
   export IMAGICK_VERSION=3.7.0 && \
   wget -O imagick.tar.gz https://github.com/Imagick/imagick/archive/refs/heads/${IMAGICK_VERSION}.tar.gz && \
   tar xvzf imagick.tar.gz && \
   cd imagick-${IMAGICK_VERSION} && \
   phpize && \
   ./configure && \
   make && \
   make install && \
   docker-php-ext-enable imagick

# Cleanup
RUN apt-get remove --purge -y libicu-dev libxml2-dev libbz2-dev zlib1g-dev libc-client-dev libkrb5-dev git libmagickwand-dev ruby-dev automake libtool \
&& rm -rf /var/lib/apt/lists/*

COPY imagick.xml /etc/ImageMagick-6/policy.xml

## V8 runtime
COPY --from=lukastrkan/libv8:10.7.193 /opt/libv8 /opt/v8/

RUN cd /tmp && \
    wget https://github.com/phpv8/v8js/archive/refs/heads/php8.tar.gz && \
    tar xvzf php8.tar.gz && \
    cd v8js-php8 && \
    phpize     &&  \
    ./configure --with-v8js=/opt/v8 LDFLAGS="-lstdc++" CPPFLAGS="-DV8_COMPRESS_POINTERS "     &&  \
    make  -j4   &&  \
    make install && \
    echo "extension=v8js.so" > /usr/local/etc/php/conf.d/v8js.ini && \
    rm -rf /tmp/*

FROM php:8.4-cli-bookworm

WORKDIR /var/www/html

EXPOSE 80

COPY --from=builder / /
