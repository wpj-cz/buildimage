FROM php:7.1-apache-stretch

RUN apt-get update \
   # Core PHP modules \
   && apt install -y --no-install-recommends libicu-dev libxml2-dev libjpeg62-turbo-dev libbz2-dev libmcrypt-dev zlib1g-dev libc-client-dev libkrb5-dev libmagickwand-dev libxslt-dev mysql-client \
   && docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
   && docker-php-ext-configure gd --with-jpeg-dir=/usr --with-png-dir=/usr \
   && docker-php-ext-install pdo_mysql intl mbstring soap bz2 mcrypt xmlrpc zip bcmath imap gd xsl calendar opcache \
   \
   # PECL
   && apt install -y --no-install-recommends libmemcached-dev \
   && pecl install memcached imagick apcu \
   && docker-php-ext-enable memcached imagick apcu \
   \
   # Fontcustom - font icons \
   && apt install -y --no-install-recommends ruby ruby-dev fontforge woff-tools automake libtool \
   && gem install fontcustom:1.3.8 \
   \
   # SASSPHP
   && apt install -y --no-install-recommends git \
   && git clone --recursive https://github.com/absalomedia/sassphp.git /tmp/sassphp -b 0.6.1 \
   && cd /tmp/sassphp \
   && cd lib/libsass && make && cd ../.. \
   && docker-php-ext-configure /tmp/sassphp \
   && docker-php-ext-install /tmp/sassphp \
   && rm -r /tmp/sassphp \
   \
   # Additional apps
   && apt install -y --no-install-recommends nano wget ghostscript less \
   \
   # Cleanup
   && apt-get remove --purge -y libicu-dev libxml2-dev libbz2-dev libmcrypt-dev zlib1g-dev libc-client-dev libkrb5-dev git libmagickwand-dev ruby-dev automake libtool \
   && rm -rf /var/lib/apt/lists/*
