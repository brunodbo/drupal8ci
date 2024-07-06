# Tweaked version of https://github.com/docker-library/drupal/blob/0bc267208f3f1405b8441588a48e0004508f65f8/9.4/php8.1/apache-bullseye/Dockerfile

# <Tweaks>

# from https://www.drupal.org/docs/8/system-requirements/drupal-8-php-requirements
  FROM php:8.3-bullseye

  # install the PHP extensions we need
    RUN set -eux; \
    \
    if command -v a2enmod; then \
    a2enmod rewrite; \
    fi; \
    \
    savedAptMark="$(apt-mark showmanual)"; \
    \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    libfreetype6-dev \
    libjpeg-dev \
    libpng-dev \
    libpq-dev \
    libzip-dev \
    ; \
    \
    docker-php-ext-configure gd \
      --with-freetype \
		  --with-jpeg=/usr \
    ; \
    \
    docker-php-ext-install -j "$(nproc)" \
    gd \
    opcache \
    pdo_mysql \
    pdo_pgsql \
    zip \
    ; \
    \
  # reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
    apt-mark auto '.*' > /dev/null; \
    apt-mark manual $savedAptMark; \
    ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
    | awk '/=>/ { print $3 }' \
    | sort -u \
    | xargs -r dpkg-query -S \
    | cut -d: -f1 \
    | sort -u \
    | xargs -rt apt-mark manual; \
    \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/*

  # set recommended PHP.ini settings
  # see https://secure.php.net/manual/en/opcache.installation.php
    RUN { \
    echo 'opcache.memory_consumption=128'; \
    echo 'opcache.interned_strings_buffer=8'; \
    echo 'opcache.max_accelerated_files=4000'; \
    echo 'opcache.revalidate_freq=60'; \
    echo 'opcache.fast_shutdown=1'; \
} > /usr/local/etc/php/conf.d/opcache-recommended.ini

    WORKDIR /var/www/html

# </Tweaks>

# Set container timezone
ENV TZ=America/Vancouver
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Prevent https://stackoverflow.com/questions/46247032/how-to-solve-invoke-rc-d-policy-rc-d-denied-execution-of-start-when-building
# when installing rsync
RUN echo exit 0 > /usr/sbin/policy-rc.d

RUN apt-get update && apt-get install -y \
  git \
  imagemagick \
  libmagickwand-dev \
  mariadb-client \
  rsync \
  sudo \
  unzip \
  vim \
  wget \
  && docker-php-ext-install bcmath \
  && docker-php-ext-install mysqli \
  && docker-php-ext-install pdo \
  && docker-php-ext-install pdo_mysql

RUN apt-get install openssh-client gnupg apt-transport-https ca-certificates -y
RUN curl -sL https://deb.nodesource.com/setup_18.x | bash -
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
RUN apt-get update -y && apt-get install nodejs -y

# Cypress dependencies
# https://docs.cypress.io/guides/guides/continuous-integration.html#Dependencies
RUN apt-get install -y \
  libgtk2.0-0 \
  libgtk-3-0 \
  libgbm-dev \
  libnotify-dev \
  libgconf-2-4 \
  libnss3 libxss1 \
  libasound2 \
  libxtst6 \
  xauth \
  xvfb

# Remove the memory limit for the CLI only.
RUN echo 'memory_limit = -1' > /usr/local/etc/php/php-cli.ini

# Remove the vanilla Drupal project that comes with this image.
#RUN rm -rf ..?* .[!.]* *

# Change docroot since we use BLT.
RUN sed -ri -e 's!/var/www/html!/var/www/html/docroot!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www!/var/www/html/docroot!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# Install composer.
COPY scripts/composer-installer.sh /tmp/composer-installer.sh
RUN chmod +x /tmp/composer-installer.sh
RUN /tmp/composer-installer.sh
RUN mv composer.phar /usr/local/bin/composer

# Install XDebug.
#RUN pecl install xdebug \
#    && docker-php-ext-enable xdebug

# Install Robo CI.
#RUN wget https://robo.li/robo.phar
#RUN chmod +x robo.phar && mv robo.phar /usr/local/bin/robo

# Install Dockerize.
ENV DOCKERIZE_VERSION v0.6.0
RUN wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && rm dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz

# Install ImageMagic to take screenshots.
#RUN pecl install imagick \
#    && docker-php-ext-enable imagick

# Install Chrome browser.
#RUN apt-get install --yes gnupg2 apt-transport-https
#RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
#RUN sh -c 'echo "deb https://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list'
#RUN apt-get update
#RUN apt-get install --yes google-chrome-unstable
