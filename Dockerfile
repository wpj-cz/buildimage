# From https://hub.docker.com/layers/mbukovy/php82v8js/latest/images/sha256-c1625f4ee805a4add023250c40fddf0f5a8ad22d46a5626ed82c588de8974951?context=explore
FROM php:8.2-cli-bullseye as v8jsBuild

ENV V8_VERSION=11.1.277.13
ENV V8JS_VERSION=php8

RUN apt-get update &&     apt-get install -y --no-install-recommends      build-essential      cron      curl      libglib2.0-dev      libtinfo5      libtinfo-dev      libxml2      iproute2      gnupg2      libyaml-dev      libxml2-dev      git      libzip-dev      libonig-dev      libpng-dev      libjpeg-dev      libfreetype6-dev      python      zlib1g-dev      netcat      unzip      procps

RUN cd /tmp     &&  \
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git --progress --verbose     &&  \
    export PATH="$PATH:/tmp/depot_tools"     &&  \
    fetch v8     &&  \
    cd v8     &&  \
    git checkout $V8_VERSION     &&  \
    gclient sync     &&  \
    tools/dev/v8gen.py -vv x64.release -- is_component_build=true use_custom_libcxx=false     &&  \
    cd /tmp/v8     &&  \
    ninja -j 4 -C out.gn/x64.release/ && \
    mkdir -p /opt/v8/lib &&  \
    mkdir -p /opt/v8/include     &&  \
    cp out.gn/x64.release/lib*.so out.gn/x64.release/*_blob.bin out.gn/x64.release/icudtl.dat /opt/v8/lib/     &&  \
    cp -R include/* /opt/v8/include/



FROM php:8.2-cli-bullseye

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
   export UWSGI_VERSION=master; \
   cd /usr/src; \
   curl -fsSL -o uwsgi.tar.gz https://github.com/unbit/uwsgi/archive/refs/heads/${UWSGI_VERSION}.tar.gz; \
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
   && pip install xlsx-streaming json-stream \
   \
   # Cleanup
   && apt-get remove --purge -y libicu-dev libxml2-dev libbz2-dev zlib1g-dev libc-client-dev libkrb5-dev git libmagickwand-dev ruby-dev automake libtool \
   && rm -rf /var/lib/apt/lists/*

COPY imagick.xml /etc/ImageMagick-6/policy.xml

## V8 runtime
COPY --from=v8jsBuild /opt/v8/ /opt/v8/

RUN cd /tmp && \
    wget https://github.com/phpv8/v8js/archive/refs/heads/php8.tar.gz && \
    tar xvzf php8.tar.gz && \
    cd v8js-php8 && \
    phpize     &&  \
    ./configure --with-v8js=/opt/v8 LDFLAGS="-lstdc++" CPPFLAGS="-DV8_COMPRESS_POINTERS -DV8_ENABLE_SANDBOX"     &&  \
    make  -j4   &&  \
    make install && \
    echo "extension=v8js.so" > /usr/local/etc/php/conf.d/v8js.ini
