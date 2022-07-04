FROM php:8.1-cli-bullseye

WORKDIR /var/www/html

EXPOSE 80

# use TLSv1.0
RUN sed -i 's/MinProtocol = TLSv1.2/MinProtocol = TLSv1.0/g' /etc/ssl/openssl.cnf

COPY imagick.xml /var/www/.config/ImageMagick/policy.xml
COPY imagick.xml /root/.config/ImageMagick/policy.xml

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
   export UWSGI_VERSION=2799f48749243a82036b63820c35c696fa302d89; \
   cd /usr/src; \
   curl -fsSL -o uwsgi.tar.gz https://github.com/unbit/uwsgi/archive/${UWSGI_VERSION}.tar.gz; \
   tar -xvzf uwsgi.tar.gz; \
   cd uwsgi-${UWSGI_VERSION}; \
   # uwsgi tries to find libphp8
   ln -s libphp.so /usr/local/lib/libphp8.so; \
   # Remove '-pie' from ldflags
   sed -i "s/p_ldflags_blacklist = ('-Wl,--no-undefined',)/p_ldflags_blacklist = ('-Wl,--no-undefined', '-pie')/" uwsgiconfig.py;\
   python uwsgiconfig.py --build core; \
   python uwsgiconfig.py --plugin plugins/corerouter core; \
   python uwsgiconfig.py --plugin plugins/http core; \
   python uwsgiconfig.py --plugin plugins/cheaper_busyness core; \
   python uwsgiconfig.py --plugin plugins/router_static core; \
   UWSGICONFIG_PHPDIR=/usr/local python uwsgiconfig.py --plugin plugins/php core php ; \
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
   && apt install -y --no-install-recommends libicu-dev libxml2-dev libjpeg62-turbo-dev libbz2-dev zlib1g-dev libc-client-dev libmagickwand-dev libxslt-dev libzip-dev mariadb-client libonig-dev \
   && docker-php-ext-install pdo_mysql intl mbstring soap bz2 zip bcmath gd xsl calendar opcache gettext sockets \
   \
   # PECL
   && apt install -y --no-install-recommends libmemcached-dev librabbitmq-dev \
   && pecl install memcached imagick apcu amqp \
   && docker-php-ext-enable memcached imagick apcu amqp sockets \
   \
   # Additional apps
   && apt install -y --no-install-recommends nano wget ghostscript less unzip python3-pip \
   # Install xlsx-streaming python library
   && pip install xlsx-streaming \
   \
   # Cleanup
   && apt-get remove --purge -y libicu-dev libxml2-dev libbz2-dev zlib1g-dev libc-client-dev libkrb5-dev git libmagickwand-dev ruby-dev automake libtool \
   && rm -rf /var/lib/apt/lists/*
