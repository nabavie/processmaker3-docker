#Stage 1
FROM debian:bookworm-slim AS builder

LABEL stage="builder"

RUN echo "deb http://deb.debian.org/debian bookworm main" > /etc/apt/sources.list && \
    echo "deb http://deb.debian.org/debian-security bookworm-security main" >> /etc/apt/sources.list && \
    echo "deb http://deb.debian.org/debian bookworm-updates main" >> /etc/apt/sources.list && \
    rm -f /etc/apt/sources.list.d/debian.sources

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates && \
    update-ca-certificates && \
    test -f /etc/ssl/certs/ca-certificates.crt || { echo "Error: /etc/ssl/certs/ca-certificates.crt not found"; exit 1; } && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        gcc \
        g++ \
        make \
        autoconf \
        libc-dev \
        pkg-config \
        bison \
        gawk \
        re2c \
        patch \
        libpng-dev \
        libjpeg-dev \
        libonig-dev \
        libxml2-dev \
        libzip-dev \
        libpq-dev \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libxslt1-dev \
        libldap2-dev \
        unixodbc-dev \
        libltdl-dev \
        libcurl4-openssl-dev \
        libssl-dev \
        libgmp-dev \
        libmariadb-dev-compat \
        libmariadb-dev \
        libsqlite3-dev \
        libbz2-dev \
        libedit-dev \
        libreadline-dev \
        libargon2-dev \
        libsodium-dev \
        libicu-dev \
        libtidy-dev \
        libxmlsec1-dev \
        libzstd-dev \
        liblz4-dev \
        libaio-dev \
        wget \
        curl \
        file \
        git \
        unzip \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/include/x86_64-linux-gnu/gmp.h /usr/include/gmp.h

COPY dependencies/zlib-1.3.1.tar.gz /tmp/zlib-1.3.1.tar.gz
RUN echo "=== CRITICAL: Installing secure zlib 1.3.1 to fix CVE-2023-45853 ===" && \
    cd /tmp && \
    file zlib-1.3.1.tar.gz | grep -q "gzip compressed data" || { echo "Error: Invalid zlib archive"; exit 1; } && \
    tar xzf zlib-1.3.1.tar.gz && \
    cd zlib-1.3.1 && \
    ./configure --prefix=/usr/local --libdir=/usr/local/lib --includedir=/usr/local/include && \
    make -j$(nproc) && \
    make install && \
    echo "/usr/local/lib" > /etc/ld.so.conf.d/zlib-secure.conf && \
    ldconfig && \
    cd /tmp && rm -rf zlib-1.3.1* && \
    echo "=== Secure zlib 1.3.1 installation completed ==="

COPY dependencies/openssl-1.1.1w.tar.gz /openssl-1.1.1w.tar.gz
RUN file openssl-1.1.1w.tar.gz | grep -q "gzip compressed data" || { echo "Error: Invalid OpenSSL archive"; exit 1; } && \
    tar xzf openssl-1.1.1w.tar.gz && \
    cd openssl-1.1.1w && \
    ./config --prefix=/usr/local/openssl11 --openssldir=/usr/local/openssl11/shared shared && \
    make && make install && \
    cd .. && rm -rf openssl-1.1.1w* && \
    echo "/usr/local/openssl11/lib" > /etc/ld.so.conf.d/openssl11.conf && \
    ldconfig

COPY dependencies/php-src-security /usr/src/php
RUN test -f /usr/src/php/configure.ac || { echo "Error: PHP source directory is invalid"; exit 1; } && \
    cd /usr/src/php && ./buildconf --force

RUN mkdir -p /usr/local/lib/pkgconfig && \
    cat > /usr/local/lib/pkgconfig/zlib.pc << 'EOF'
prefix=/usr/local
exec_prefix=${prefix}
libdir=${exec_prefix}/lib
includedir=${prefix}/include

Name: zlib
Description: zlib compression library
Version: 1.3.1
Libs: -L${libdir} -lz
Cflags: -I${includedir}
EOF

ENV CFLAGS="-I/usr/local/openssl11/include -I/usr/local/include"
ENV LDFLAGS="-L/usr/local/openssl11/lib -L/usr/local/lib -Wl,-rpath=/usr/local/openssl11/lib -Wl,-rpath=/usr/local/lib"
ENV PKG_CONFIG_PATH="/usr/local/openssl11/lib/pkgconfig:/usr/local/lib/pkgconfig"
ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"

RUN cd /usr/src/php && ./configure \
        --prefix=/usr/local \
        --sysconfdir=/usr/local/etc \
        --enable-fpm \
        --with-fpm-user=www-data \
        --with-fpm-group=www-data \
        --with-config-file-path=/usr/local/etc/php \
        --with-config-file-scan-dir=/usr/local/etc/php/conf.d \
        --with-libdir=/lib/x86_64-linux-gnu \
        --with-freetype=/usr/include/ \
        --with-jpeg=/usr/include/ \
        --enable-mbstring \
        --with-zip \
        --enable-exif \
        --enable-pcntl \
        --enable-soap \
        --with-xsl \
        --with-ldap=/usr \
        --with-mysqli=mysqlnd \
        --with-pdo-mysql=mysqlnd \
        --with-pgsql=shared,/usr \
        --with-pdo-pgsql=shared,/usr \
        --enable-gd \
        --with-curl \
        --with-openssl=/usr/local/openssl11 \
        --with-gmp \
        --enable-bcmath \
        --with-bz2 \
        --with-readline=/usr \
        --with-sodium \
        --with-password-argon2 \
        --with-zlib=/usr/local \
        --with-zlib-dir=/usr/local \
        --enable-opcache \
    && make -j$(nproc) \
    && make install

RUN mkdir -p /usr/local/etc/php/conf.d /usr/local/etc/php-fpm.d /var/run/php /usr/local/var/log && \
    cp /usr/src/php/php.ini-production /usr/local/etc/php/php.ini && \
    cp /usr/src/php/sapi/fpm/php-fpm.conf /usr/local/etc/php-fpm.conf && \
    cp /usr/src/php/sapi/fpm/www.conf /usr/local/etc/php-fpm.d/www.conf && \
    sed -i 's|include=.*|include=/usr/local/etc/php-fpm.d/*.conf|g' /usr/local/etc/php-fpm.conf && \
    sed -i 's|^;error_log = log/php-fpm.log|error_log = /var/log/php-fpm.log|' /usr/local/etc/php-fpm.conf && \
    sed -i 's|^user = nobody|user = www-data|' /usr/local/etc/php-fpm.d/www.conf && \
    sed -i 's|^group = nobody|group = www-data|' /usr/local/etc/php-fpm.d/www.conf && \
    sed -i 's|^listen = 127.0.0.1:9000|listen = /var/run/php/php-fpm.sock|' /usr/local/etc/php-fpm.d/www.conf && \
    sed -i 's|^;listen.owner = www-data|listen.owner = www-data|' /usr/local/etc/php-fpm.d/www.conf && \
    sed -i 's|^;listen.group = www-data|listen.group = www-data|' /usr/local/etc/php-fpm.d/www.conf && \
    sed -i 's|^;listen.mode =.*|listen.mode = 0660|' /usr/local/etc/php-fpm.d/www.conf && \
    sed -i 's|^;slowlog = log/$pool.log.slow|slowlog = /var/log/php-fpm-slow.log|' /usr/local/etc/php-fpm.d/www.conf && \
    echo '; Security configuration for ProcessMaker' >> /usr/local/etc/php-fpm.d/www.conf && \
    echo 'php_admin_value[auto_prepend_file] = /opt/processmaker/workflow/public_html/security-filter.php' >> /usr/local/etc/php-fpm.d/www.conf && \
    touch /var/log/php-fpm.log /var/log/php-fpm-slow.log && \
    chown www-data:www-data /var/log/php-fpm*.log && \
    chmod 664 /var/log/php-fpm*.log && \
    /usr/local/sbin/php-fpm --fpm-config /usr/local/etc/php-fpm.conf --test

COPY dependencies/go-pear.phar /tmp/go-pear.phar
RUN php /tmp/go-pear.phar && rm /tmp/go-pear.phar

# Install Oracle Instant Client
COPY dependencies/instantclient-basic-linux.x64-21.9.0.0.0dbru.zip /tmp/
COPY dependencies/instantclient-sdk-linux.x64-21.9.0.0.0dbru.zip /tmp/
RUN mkdir -p /opt/oracle && \
    unzip /tmp/instantclient-basic-linux.x64-21.9.0.0.0dbru.zip -d /opt/oracle && \
    unzip /tmp/instantclient-sdk-linux.x64-21.9.0.0.0dbru.zip -d /opt/oracle && \
    rm -f /tmp/instantclient-basic-linux.x64-21.9.0.0.0dbru.zip /tmp/instantclient-sdk-linux.x64-21.9.0.0.0dbru.zip && \
    echo "/opt/oracle/instantclient_21_9" > /etc/ld.so.conf.d/oracle-instantclient.conf && \
    ldconfig && \
    test -f /opt/oracle/instantclient_21_9/libclntsh.so || { echo "Error: Oracle Instant Client libclntsh.so not found"; exit 1; } && \
    test -f /opt/oracle/instantclient_21_9/libocci.so || { echo "Error: Oracle Instant Client libocci.so not found"; exit 1; }

ENV LD_LIBRARY_PATH="/usr/local/lib:/opt/oracle/instantclient_21_9:$LD_LIBRARY_PATH"
ENV ORACLE_HOME="/opt/oracle/instantclient_21_9"

# Install Microsoft ODBC Driver 17 for SQL Server
COPY dependencies/libmcrypt4_2.5.8-3.4+b1_amd64.deb /tmp/libmcrypt4.deb
COPY dependencies/libmcrypt-dev_2.5.8-3.4+b1_amd64.deb /tmp/libmcrypt-dev.deb
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gnupg2 \
        apt-transport-https && \
    curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    echo "deb [arch=amd64] https://packages.microsoft.com/debian/12/prod bookworm main" > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y --no-install-recommends msodbcsql17 && \
    echo "[ODBC Driver 17 for SQL Server]\nDescription=Microsoft ODBC Driver 17 for SQL Server\nDriver=/opt/microsoft/msodbcsql17/lib64/libmsodbcsql-17.10.so.6.1\nSetup=/opt/microsoft/msodbcsql17/lib64/libmsodbcsql-17.10.so.6.1\n" > /etc/odbcinst.ini && \
    apt-get install -y --no-install-recommends unixodbc-dev && \
    dpkg -i /tmp/libmcrypt4.deb /tmp/libmcrypt-dev.deb || true && \
    apt-get install -f -y && \
    find /usr/lib /usr/lib/x86_64-linux-gnu -name '*.la' -delete && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/libmcrypt4.deb /tmp/libmcrypt-dev.deb

COPY dependencies/oci8-2.2.0.tgz /tmp/oci8.tar.gz
COPY dependencies/mcrypt-1.0.4.tgz /tmp/mcrypt-1.0.4.tgz
COPY dependencies/sqlsrv-5.10.1.tgz /tmp/sqlsrv.tar.gz
COPY dependencies/pdo_sqlsrv-5.10.1.tgz /tmp/pdo_sqlsrv.tar.gz
COPY dependencies/redis-5.3.7.tgz /tmp/redis.tar.gz
COPY dependencies/LZF-1.7.0.tgz /tmp/lzf.tar.gz
COPY dependencies/timezonedb-2024.2.tgz /tmp/timezonedb.tar.gz

RUN EXT_DIR=$(php -r "echo ini_get('extension_dir');") && \
    mkdir -p "$EXT_DIR" && \
    echo "=== Building OCI8 extension ===" && \
    tar xzf /tmp/oci8.tar.gz -C /tmp && \
    test -d /tmp/oci8-2.2.0 || { echo "Error: oci8-2.2.0 directory not found after extraction"; exit 1; } && \
    cd /tmp/oci8-2.2.0 && \
    phpize && \
    ./configure --with-oci8=instantclient,/opt/oracle/instantclient_21_9 || { echo "Error: oci8 configure failed"; exit 1; } && \
    make && make install && \
    echo "=== Building mcrypt extension ===" && \
    tar xzf /tmp/mcrypt-1.0.4.tgz -C /tmp && \
    cd /tmp/mcrypt-1.0.4 && phpize && ./configure && make && make install && \
    echo "=== Building sqlsrv extension ===" && \
    tar xzf /tmp/sqlsrv.tar.gz -C /tmp && \
    cd /tmp/sqlsrv-5.10.1 && phpize && ./configure && make && make install && \
    echo "=== Building pdo_sqlsrv extension ===" && \
    tar xzf /tmp/pdo_sqlsrv.tar.gz -C /tmp && \
    cd /tmp/pdo_sqlsrv-5.10.1 && phpize && ./configure && make && make install && \
    echo "=== Building redis extension ===" && \
    tar xzf /tmp/redis.tar.gz -C /tmp && \
    cd /tmp/redis-5.3.7 && phpize && ./configure && make && make install && \
    echo "=== Building lzf extension ===" && \
    tar xzf /tmp/lzf.tar.gz -C /tmp && \
    LZF_DIR=$(find /tmp -maxdepth 1 -type d -name 'lzf-*' -o -name 'LZF-*' | head -n 1) && \
    cd "$LZF_DIR" && phpize && ./configure && make && make install && \
    echo "=== Building timezonedb extension ===" && \
    tar xzf /tmp/timezonedb.tar.gz -C /tmp && \
    cd /tmp/timezonedb-2024.2 && phpize && ./configure && make && make install && \
    rm -rf /tmp/*.tar.gz /tmp/oci8* /tmp/mcrypt* /tmp/sqlsrv* /tmp/pdo_sqlsrv* /tmp/redis* /tmp/lzf* /tmp/timezonedb*

RUN EXT_DIR=$(php -r "echo ini_get('extension_dir');") && \
    echo "extension=oci8.so" > /usr/local/etc/php/conf.d/oci8.ini && \
    echo "extension=mcrypt.so" > /usr/local/etc/php/conf.d/mcrypt.ini && \
    echo "extension=sqlsrv.so" > /usr/local/etc/php/conf.d/sqlsrv.ini && \
    echo "extension=pdo_sqlsrv.so" > /usr/local/etc/php/conf.d/pdo_sqlsrv.ini && \
    echo "extension=redis.so" > /usr/local/etc/php/conf.d/redis.ini && \
    echo "extension=lzf.so" > /usr/local/etc/php/conf.d/lzf.ini && \
    echo "extension=timezonedb.so" > /usr/local/etc/php/conf.d/timezonedb.ini && \
    echo "extension=pgsql.so" > /usr/local/etc/php/conf.d/pgsql.ini && \
    echo "extension=pdo_pgsql.so" > /usr/local/etc/php/conf.d/pdo_pgsql.ini

# Stage 2: Runtime stage
FROM debian:bookworm-slim AS runtime

LABEL maintainer="ProcessMaker DevOps"
LABEL description="ProcessMaker with PHP 7.4 security backports on Debian Bookworm with OpenSSL 1.1 compatibility and CVE-2023-45853 fix"
LABEL version="1.5"

RUN echo "deb http://deb.debian.org/debian bookworm main" > /etc/apt/sources.list && \
    echo "deb http://deb.debian.org/debian-security bookworm-security main" >> /etc/apt/sources.list && \
    echo "deb http://deb.debian.org/debian bookworm-updates main" >> /etc/apt/sources.list && \
    rm -f /etc/apt/sources.list.d/debian.sources

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        apache2 \
        ca-certificates \
        libpng16-16 \
        libjpeg62-turbo \
        libonig5 \
        libxml2 \
        libzip4 \
        libpq5 \
        libfreetype6 \
        libxslt1.1 \
        libldap-2.5-0 \
        unixodbc \
        libltdl7 \
        odbcinst \
        libodbc2 \
        libaio1 \
        libcurl4 \
        libgmp10 \
        libbz2-1.0 \
        libedit2 \
        libreadline8 \
        libargon2-1 \
        libsodium23 \
        libicu72 \
        libtidy5deb1 \
        libzstd1 \
        liblz4-1 \
        cron \
        socat \
        redis-tools \
        curl \
        procps \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/bin/php /usr/local/bin/php
COPY --from=builder /usr/local/sbin/php-fpm /usr/local/sbin/php-fpm
COPY --from=builder /usr/local/lib/php /usr/local/lib/php
COPY --from=builder /usr/local/etc/php /usr/local/etc/php
COPY --from=builder /usr/local/etc/php-fpm.conf /usr/local/etc/php-fpm.conf
COPY --from=builder /usr/local/etc/php-fpm.d /usr/local/etc/php-fpm.d
COPY --from=builder /usr/local/include/php /usr/local/include/php

COPY --from=builder /usr/local/lib/libz* /usr/local/lib/
COPY --from=builder /usr/local/include/zlib.h /usr/local/include/
COPY --from=builder /usr/local/include/zconf.h /usr/local/include/
COPY --from=builder /etc/ld.so.conf.d/zlib-secure.conf /etc/ld.so.conf.d/

COPY --from=builder /usr/local/openssl11 /usr/local/openssl11
COPY --from=builder /etc/ld.so.conf.d/openssl11.conf /etc/ld.so.conf.d/

COPY --from=builder /opt/oracle /opt/oracle
COPY --from=builder /etc/ld.so.conf.d/oracle-instantclient.conf /etc/ld.so.conf.d/

COPY dependencies/libmcrypt4_2.5.8-3.4+b1_amd64.deb /tmp/libmcrypt4.deb
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gnupg2 \
        apt-transport-https && \
    curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    echo "deb [arch=amd64] https://packages.microsoft.com/debian/12/prod bookworm main" > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y --no-install-recommends msodbcsql17 && \
    echo "[ODBC Driver 17 for SQL Server]\nDescription=Microsoft ODBC Driver 17 for SQL Server\nDriver=/opt/microsoft/msodbcsql17/lib64/libmsodbcsql-17.10.so.6.1\nSetup=/opt/microsoft/msodbcsql17/lib64/libmsodbcsql-17.10.so.6.1\n" > /etc/odbcinst.ini && \
    dpkg -i /tmp/libmcrypt4.deb || true && \
    apt-get install -f -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/libmcrypt4.deb

RUN ldconfig

RUN odbcinst -q -d -n "ODBC Driver 17 for SQL Server" || { echo "Error: ODBC Driver 17 not found"; exit 1; }

ENV LD_LIBRARY_PATH="/usr/local/lib:/opt/oracle/instantclient_21_9:$LD_LIBRARY_PATH"
ENV ORACLE_HOME="/opt/oracle/instantclient_21_9"
ENV PATH="$ORACLE_HOME:$PATH"

RUN mkdir -p /var/run/php /var/log && \
    touch /var/log/php-fpm.log /var/log/php-fpm-slow.log && \
    chown -R www-data:www-data /var/run/php /var/log/php-fpm*.log && \
    chmod 775 /var/run/php && \
    chmod 664 /var/log/php-fpm*.log

RUN a2enmod rewrite headers expires proxy_fcgi setenvif && \
    echo '<FilesMatch \.php$>' > /etc/apache2/conf-available/php-fpm.conf && \
    echo '    SetHandler "proxy:unix:/var/run/php/php-fpm.sock|fcgi://localhost"' >> /etc/apache2/conf-available/php-fpm.conf && \
    echo '</FilesMatch>' >> /etc/apache2/conf-available/php-fpm.conf && \
    a2enconf php-fpm && \
    echo "ServerName localhost" >> /etc/apache2/apache2.conf && \
    echo "ServerTokens Prod" >> /etc/apache2/apache2.conf && \
    echo "ServerSignature Off" >> /etc/apache2/apache2.conf

RUN mkdir -p /opt/processmaker /opt/processmaker/shared/sites/workflow/log /opt/secure-plugins /opt/decrypted-plugins /var/log/php && \
    chown -R www-data:www-data /opt/processmaker /opt/secure-plugins /opt/decrypted-plugins /var/log/php && \
    chmod -R 775 /opt/processmaker && \
    chmod -R 700 /opt/secure-plugins /opt/decrypted-plugins && \
    chmod -R 775 /var/log/php

COPY php.ini /usr/local/etc/php/php.ini

RUN echo "=== CVE-2023-45853 Security Verification ===" && \
    ldconfig -p | grep libz && \
    php -m | grep -q "zlib" || { echo "Error: zlib extension not loaded"; exit 1; } && \
    php -r "\
    \$version = phpversion('zlib');\
    if (\$version === false) {\
        echo 'Error: zlib extension not available' . PHP_EOL;\
        exit(1);\
    }\
    echo 'PHP zlib version: ' . \$version . PHP_EOL;\
    if (version_compare(\$version, '1.3.1', '>=')) {\
        echo 'SUCCESS: zlib version is secure against CVE-2023-45853' . PHP_EOL;\
    } else {\
        echo 'WARNING: zlib version may still be vulnerable' . PHP_EOL;\
    }\
    " && \
    echo "=== Verifying PHP Extensions ===" && \
    php -m | grep -E "(oci8|redis|lzf|mcrypt|sqlsrv|pdo_sqlsrv|timezonedb|zlib|pgsql|pdo_pgsql)" && \
    echo "=== PHP Version ===" && \
    php -v

COPY plugins.tar.gz.enc /opt/secure-plugins/
COPY entrypoint.sh /opt/entrypoint.sh
COPY monitor.sh /opt/monitor.sh
COPY php-wrapper.sh /opt/php-wrapper.sh

RUN chown www-data:www-data /opt/secure-plugins/plugins.tar.gz.enc /opt/entrypoint.sh /opt/monitor.sh /opt/php-wrapper.sh && \
    chmod 600 /opt/secure-plugins/plugins.tar.gz.enc && \
    chmod 700 /opt/entrypoint.sh /opt/monitor.sh /opt/php-wrapper.sh

RUN touch /opt/processmaker/pm_cron.log && \
    chown www-data:www-data /opt/processmaker/pm_cron.log && \
    chmod 664 /opt/processmaker/pm_cron.log

EXPOSE 80 443

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

ENTRYPOINT ["/opt/entrypoint.sh"]
