FROM php:7.4-cli-bullseye

WORKDIR /var/www/html

EXPOSE 80

# use TLSv1.0
RUN sed -i 's/MinProtocol = TLSv1.2/MinProtocol = TLSv1.0/g' /etc/ssl/openssl.cnf

COPY uwsgi_profile.ini /usr/src/wpj.ini

# UWSGI
RUN set -eux; \
   savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		python \
		libargon2-dev \
      libcurl4-openssl-dev \
      libedit-dev \
      libsodium-dev \
      libsqlite3-dev \
      libssl-dev \
      libxml2-dev \
      zlib1g-dev \
      libpcre3-dev \
      libreadline-dev \
      libonig-dev \
    ;\
   export UWSGI_VERSION=php_81_app; \
   cd /usr/src; \
   curl -fsSL -o uwsgi.tar.gz https://github.com/wpj-cz/uwsgi/archive/refs/heads/${UWSGI_VERSION}.tar.gz; \
   tar -xvzf uwsgi.tar.gz; \
   cd uwsgi-${UWSGI_VERSION}; \
   mv /usr/src/wpj.ini buildconf/wpj.ini; \
   # uwsgi tries to find libphp8
   ln -s libphp.so /usr/local/lib/libphp8.so; \
   # Remove '-pie' from ldflags
   sed -i "s/p_ldflags_blacklist = ('-Wl,--no-undefined',)/p_ldflags_blacklist = ('-Wl,--no-undefined', '-pie')/" uwsgiconfig.py; \
   UWSGICONFIG_PHPDIR=/usr/local python uwsgiconfig.py --build wpj; \
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
   && apt install -y --no-install-recommends libicu-dev libxml2-dev libjpeg62-turbo-dev libwebp-dev libbz2-dev zlib1g-dev libc-client-dev libmagickwand-dev libxslt-dev libzip-dev mariadb-client libonig-dev \
   && docker-php-ext-configure gd --with-jpeg=/usr --with-webp=/usr \
   && docker-php-ext-install pdo_mysql intl mbstring soap bz2 zip bcmath gd xsl calendar opcache gettext sockets \
   # PECL
   && apt install -y --no-install-recommends libmemcached-dev librabbitmq-dev \
   && pecl install memcached imagick apcu amqp \
   && docker-php-ext-enable memcached imagick apcu amqp sockets \
   # Additional apps
   && apt install -y --no-install-recommends nano procps iputils-ping wget ghostscript less unzip python3-pip \
   # Install xlsx-streaming python library
   && pip install xlsx-streaming \
   \
   # Cleanup
   && apt-get remove --purge -y libicu-dev libxml2-dev libbz2-dev zlib1g-dev libc-client-dev libkrb5-dev git libmagickwand-dev ruby-dev automake libtool \
   && rm -rf /var/lib/apt/lists/*

COPY imagick.xml /etc/ImageMagick-6/policy.xml