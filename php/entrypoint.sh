#!/bin/bash

set -e

mkdir -p /var/log/php
chown www-data:www-data /var/log/php
chmod 775 /var/log/php

# Setup ProcessMaker cron jobs
PHP_BIN="/usr/local/bin/php"
CRONTAB_FILE="/etc/cron.d/processmaker"
echo "Registering ProcessMaker cron jobs..."
cat <<EOF > "$CRONTAB_FILE"
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
*/1 * * * * www-data $PHP_BIN -f /opt/processmaker/workflow/engine/bin/cron.php +force >> /opt/processmaker/pm_cron.log 2>&1
*/2 * * * * www-data $PHP_BIN -f /opt/processmaker/workflow/engine/bin/timereventcron.php +force >> /opt/processmaker/pm_cron.log 2>&1
*/3 * * * * www-data $PHP_BIN -f /opt/processmaker/workflow/engine/bin/messageeventcron.php +force >> /opt/processmaker/pm_cron.log 2>&1
*/5 * * * * www-data $PHP_BIN -f /opt/processmaker/workflow/engine/bin/sendnotificationscron.php +force >> /opt/processmaker/pm_cron.log 2>&1
*/5 * * * * www-data chown -R www-data:www-data /opt/processmaker/shared/sites/workflow/log /var/log/php && chmod -R 775 /opt/processmaker/shared/sites/workflow/log /var/log/php >> /opt/processmaker/pm_cron.log 2>&1
EOF
chmod 0644 "$CRONTAB_FILE"

# Start Redis proxy
echo "Starting Redis proxy..."
socat TCP-LISTEN:6379,fork TCP:pm_redis:6379 &

# Verify Redis connectivity
REDIS_HOST="pm_redis"
REDIS_PORT="6379"
if ping -c 2 $REDIS_HOST >/dev/null 2>&1; then
    echo "✓ Redis host $REDIS_HOST is reachable via ping"
else
    echo "✗ Redis host $REDIS_HOST is not reachable via ping"
fi
if nc -z -w 5 $REDIS_HOST $REDIS_PORT >/dev/null 2>&1; then
    echo "✓ Redis port $REDIS_PORT is open on $REDIS_HOST"
else
    echo "✗ Redis port $REDIS_PORT is not open on $REDIS_HOST"
fi

# Verify PHP extensions
EXT_DIR=$(php -r "echo ini_get('extension_dir');")
echo "Extension directory: $EXT_DIR"
for ext in lzf oci8 redis mcrypt sqlsrv pdo_sqlsrv timezonedb pgsql pdo_pgsql; do
    if [ -f "$EXT_DIR/$ext.so" ]; then
        echo "✓ $ext.so found"
    else
        echo "✗ $ext.so not found in $EXT_DIR"
        find /usr -name "$ext.so" 2>/dev/null || echo "  Extension not found anywhere"
    fi
done

# Test database connectivity extensions
echo "=== Testing database connectivity extensions ==="
/usr/local/bin/php -r "
\$extensions = [
    'mysqli' => 'MySQL/MariaDB support',
    'oci8' => 'Oracle Database support',
    'sqlsrv' => 'SQL Server support',
    'pdo_sqlsrv' => 'PDO SQL Server support',
    'pdo_mysql' => 'PDO MySQL support',
    'pgsql' => 'PostgreSQL support',
    'pdo_pgsql' => 'PDO PostgreSQL support',
];
foreach (\$extensions as \$ext => \$desc) {
    if (extension_loaded(\$ext)) {
        echo '✓ ' . \$ext . ' extension: LOADED (' . \$desc . ')' . \"\n\";
    } else {
        echo '✗ ' . \$ext . ' extension: NOT LOADED (' . \$desc . ')' . \"\n\";
    }
}
"

# Test PHP session functionality with Redis
echo "=== Testing PHP session functionality with Redis ==="
echo "Waiting 5 seconds for Redis to initialize..."
sleep 5
/usr/local/bin/php -r "
ob_start();
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

\$output = [];
\$output[] = 'Session save handler: ' . ini_get('session.save_handler');
\$output[] = 'Session save path: ' . ini_get('session.save_path');
\$redis_available = false;

\$redis = new Redis();
try {
    if (\$redis->connect('pm_redis', 6379, 5)) {
        \$redis->select(2);
        \$redis->ping();
        \$redis_available = true;
        \$output[] = '✓ Redis available for sessions';
        \$redis->close();
    }
} catch (Exception \$e) {
    \$output[] = '✗ Redis unavailable: ' . \$e->getMessage();
}

if (!\$redis_available) {
    \$output[] = 'Falling back to file-based sessions';
    ini_set('session.save_handler', 'files');
    ini_set('session.save_path', '/tmp');
}

try {
    session_name('TESTSESSID');
    if (session_start()) {
        \$session_id = session_id();
        \$output[] = '✓ Session start: OK, ID: ' . \$session_id;
        \$_SESSION['test'] = 'openssl_compatibility_check';
        session_write_close();

        \$redis = new Redis();
        try {
            \$redis->connect('pm_redis', 6379, 5);
            \$redis->select(2);
            \$keys = \$redis->keys('PHPREDIS_SESSION:*');
            \$output[] = 'Redis session keys found: ' . count(\$keys);
            foreach (\$keys as \$key) {
                \$value = \$redis->get(\$key);
                \$output[] = 'Key: ' . \$key . ', Value: ' . \$value;
                if (\$key === 'PHPREDIS_SESSION:' . \$session_id) {
                    \$output[] = 'Test session key found: ' . \$value;
                }
            }
            \$redis->close();
        } catch (Exception \$e) {
            \$output[] = 'Redis key check error: ' . \$e->getMessage();
        }

        session_name('TESTSESSID');
        if (session_start()) {
            if (isset(\$_SESSION['test']) && \$_SESSION['test'] === 'openssl_compatibility_check') {
                \$output[] = '✓ Session read/write: OK';
            } else {
                \$output[] = '✗ Session read/write: FAILED';
            }
            session_write_close();
            \$output[] = 'Session closed';
        } else {
            \$output[] = '✗ Session read: FAILED';
        }
    } else {
        \$output[] = '✗ Session start: FAILED';
    }
} catch (Exception \$e) {
    \$output[] = '✗ Session start: FAILED - ' . \$e->getMessage();
}

foreach (\$output as \$line) {
    echo \$line . \"\n\";
}
ob_end_flush();
"

# System status summary
echo "=== System Status Summary ==="
echo "Container started successfully at: $(date)"
echo "OpenSSL version: $(openssl version)"
echo "PHP version: $(/usr/local/bin/php -r 'echo PHP_VERSION;')"
echo "PHP-FPM status: $(pgrep -f php-fpm | wc -l) processes running"
echo "Cron status: $(pgrep -f cron | wc -l) processes running"
echo "Apache status: Starting in foreground mode..."

# Final service readiness check
if [ ! -S /var/run/php/php-fpm.sock ]; then
    echo "✗ PHP-FPM socket not ready"
    exit 1
else
    echo "✓ PHP-FPM socket ready"
fi

if ! pgrep -f cron > /dev/null; then
    echo "✗ Cron service not running"
    exit 1
else
    echo "✓ Cron service running"
fi

echo "✓ All critical services are ready"

echo "=== Starting Apache HTTP Server ==="
exec apache2ctl -D FOREGROUND