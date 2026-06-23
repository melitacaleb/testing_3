FROM php:8.2-apache

# Postgres extension + build deps
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libpq-dev \
        unzip \
        git \
    && docker-php-ext-install pdo pdo_pgsql \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Apache config: serve the app, allow .htaccess if you add any later
RUN a2enmod rewrite
COPY docker/apache-app.conf /etc/apache2/sites-available/000-default.conf

WORKDIR /var/www/html
COPY . /var/www/html

# Make sure the logs dir used by sendEmailNotification() is writable
RUN mkdir -p /var/www/html/logs && chown -R www-data:www-data /var/www/html

# Render injects $PORT at runtime; Apache's default config listens on 80,
# so we rewrite the listen directive at container start.
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 80
ENTRYPOINT ["entrypoint.sh"]
CMD ["apache2-foreground"]
