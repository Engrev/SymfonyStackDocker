<?php

/**
 * ════════════════════════════════════════════════════════════════
 *  deploy.php — Configuration Deployer
 *
 *  Installation :
 *    composer require --dev deployer/deployer
 *
 *  Usage locally (in the PHP container):
 *    vendor/bin/dep deploy pprod
 *    vendor/bin/dep deploy prod
 *    vendor/bin/dep rollback pprod
 *    vendor/bin/dep rollback prod
 *    vendor/bin/dep releases prod ← lists the releases
 *
 *  Required environment variables (injected by GitHub Actions):
 *    DEPLOY_HOST       SSH host of the server
 *    DEPLOY_USER       SSH user
 *    DEPLOY_BASE_PATH  Base path on the server
 *                      e.g.: /home/clients/xxx/sites/mon-projet
 *
 *  Structure created on the server:
 *    $DEPLOY_BASE_PATH/
 *        prod/
 *            releases/
 *                20250311_143000/   ← active release
 *                20250310_091500/   ← previous release
 *            current -> releases/20250311_143000  (symlink)
 *            shared/
 *                .env.local.php     ← to be created manually once (or generated)
 *                var/
 *                    log/
 *                    sessions/
 *                public/
 *                    uploads/
 *        pprod/
 *            (same structure)
 * ════════════════════════════════════════════════════════════════
 */

namespace Deployer;

require 'app/vendor/autoload.php';

// ── Official Symfony Recipe ─────────────────────────────────────
require 'app/vendor/deployer/deployer/recipe/symfony.php';

// ════════════════════════════════════════════════════════════════
// Common configuration
// ════════════════════════════════════════════════════════════════

// Number of releases kept on the server
set('keep_releases', 5);

// Deployer deploys from the current directory (already checked out in CI)
// no need for git clone on the server
set('repository', '');

// Shared files across all releases (unversioned)
set('shared_files', [
    '.env.local.php',
]);

// Shared dirs across all releases
set('shared_dirs', [
    'var/logs',
    'var/sessions',
    'public/uploads',
]);

// Directories with write permissions for the web process
set('writable_dirs', [
    'var',
    'var/cache',
    'var/logs',
    'var/sessions',
    'public',
    'public/uploads',
]);

// PHP CLI on the server — override possible via env variable
set('bin/php', function () {
    return getenv('SERVER_PHP_BIN') ?: '/opt/php8.4/bin/php';
});

// Compose on the server
set('bin/composer', function () {
    return getenv('SERVER_COMPOSER_BIN') ?: '/opt/php8.4/bin/composer2.phar';
});

// User of the web server — override possible via env variable
set('http_user', function () {
    return getenv('SERVER_HTTP_USER') ?: 'www-data';
});

// Environment variables for remote commands (ensure Symfony runs in the right mode)
set('env', function () {
    return [
        'APP_ENV' => get('symfony_env', 'prod'),
    ];
});

// ════════════════════════════════════════════════════════════════
//  Hosts
// ════════════════════════════════════════════════════════════════

$deployHost  = getenv('DEPLOY_HOST')      ?: 'votre-serveur.com';
$deployUser  = getenv('DEPLOY_USER')      ?: 'deployer';
$deployBase  = getenv('DEPLOY_BASE_PATH') ?: '/home/clients/xxx/sites/mon-projet';

host('pprod')
    ->setHostname($deployHost)
    ->setRemoteUser($deployUser)
    ->set('deploy_path', $deployBase . '/pprod')
    ->set('symfony_env', 'prod')      // Symfony runs in prod even in pprod
    ->set('branch', 'release')        // Deployed from the release branch
    ->set('labels', ['env' => 'pprod'])
    ->set('healthcheck_url', getenv('HEALTHCHECK_URL_PPROD') ?: '')
;

host('prod')
    ->setHostname($deployHost)
    ->setRemoteUser($deployUser)
    ->set('deploy_path', $deployBase . '/prod')
    ->set('symfony_env', 'prod')
    ->set('branch', 'main')           // Deployed from the main branch
    ->set('labels', ['env' => 'prod'])
    ->set('healthcheck_url', getenv('HEALTHCHECK_URL_PROD') ?: '')
;

// ════════════════════════════════════════════════════════════════
//  Custom tasks
// ════════════════════════════════════════════════════════════════

// ── Upload app files in CI ──────────────────────────────────────
task('deploy:update_code', function () {
    upload('app/', '{{release_path}}', [
        'options' => [
            '--exclude=.git',
            '--exclude=vendor',      // The vendors will be installed on the server via deploy:vendors
            '--exclude=var',
            '--exclude=node_modules',
            '--exclude=.editorconfig',
        ],
    ]);
});

// ── Upload of compiled assets in CI ─────────────────────────────
// The assets are built in CI and uploaded via rsync
// We do NOT build on the server (no Node required)
desc('Upload compiled assets to release');
task('deploy:upload_assets', function () {
    $localAssets = 'app/public/build/';
    if (!is_dir($localAssets)) {
        info('No compiled assets found in public/build/, skipping upload.');
        return;
    }
    upload($localAssets, '{{release_path}}/public/build/');
});

// ── Generate .env.local.php from GitHub Secrets ─────────────────
desc('Generate .env.local.php from environment variables');
task('deploy:secrets', function () {
    // Check if file already exists on the server
    if (run("if [ -f {{deploy_path}}/shared/.env.local.php ]; then echo 'exists'; else echo 'missing'; fi") === 'exists') {
        info('ℹ️ .env.local.php already exists in shared/, skipping generation.');
        return;
    }

    $appSecret = getenv('APP_SECRET') ?: bin2hex(random_bytes(16));
    $dbUser = getenv('DB_USER');
    $dbPass = getenv('DB_PASSWORD');
    $dbHost = getenv('DB_HOST') ?: '127.0.0.1';
    $dbPort = getenv('DB_PORT') ?: '3306';
    $dbName = getenv('DB_NAME');
    $dbOptions = getenv('DB_OPTIONS') ?: 'serverVersion=10.11.15-MariaDB&charset=utf8mb4';
    $messengerTransportDsn = getenv('MESSENGER_TRANSPORT_DSN') ?: 'doctrine://default?auto_setup=0';
    $mailerDsnUser = getenv('MAILER_DSN_USER');
    $mailerDsnPass = getenv('MAILER_DSN_PASSWORD');
    $mailerDsnHost = getenv('MAILER_DSN_HOST') ?: '127.0.0.1';
    $mailerDsnPort = getenv('MAILER_DSN_PORT') ?: '587';

    if (!$dbUser || !$dbPass || !$dbName) {
        info('Missing database secrets (DB_USER, DB_PASSWORD, DB_NAME), skipping .env.local.php generation.');
        return;
    }
    if (!$mailerDsnUser || !$mailerDsnPass || !$mailerDsnHost) {
        info('Missing mailer secrets (MAILER_DSN_USER, MAILER_DSN_PASSWORD, MAILER_DSN_HOST), skipping .env.local.php generation.');
        return;
    }

    $dbUrl = "mysql://$dbUser:$dbPass@$dbHost:$dbPort/$dbName?$dbOptions";
    $mailerDsn = "smtp://$mailerDsnUser:$mailerDsnPass@$mailerDsnHost:$mailerDsnPort";

    $content = "<?php\n\nreturn [\n";
    $content .= "    'APP_ENV' => 'prod',\n";
    $content .= "    'APP_SECRET' => '$appSecret',\n";
    $content .= "    'APP_SHARE_DIR' => 'var/share',\n";
    $content .= "    'DEFAULT_URI' => 'http://localhost',\n";
    $content .= "    'DATABASE_URL' => '$dbUrl',\n";
    $content .= "    'MESSENGER_TRANSPORT_DSN' => '$messengerTransportDsn',\n";
    $content .= "    'MAILER_DSN' => '$mailerDsn',\n";
    $content .= "];\n";

    $tmpFile = tempnam(sys_get_temp_dir(), 'env');
    file_put_contents($tmpFile, $content);
    
    run("mkdir -p {{deploy_path}}/shared");
    upload($tmpFile, '{{deploy_path}}/shared/.env.local.php');
    
    unlink($tmpFile);
    info('✅ .env.local.php generated in shared/');
});

// ── Check environment ───────────────────────────────────────────
desc('Check environment and PHP extensions');
task('deploy:check', function () {
    $php = get('bin/php');
    info("Checking PHP binary: $php");
    run("$php -v");
    info("Checking PDO drivers:");
    $drivers = run("$php -r 'echo implode(\", \", PDO::getAvailableDrivers());'");
    info("Available drivers: $drivers");
    
    if (str_contains($drivers, 'pgsql')) {
        info("✅ PostgreSQL driver found.");
    } else {
        info("❌ PostgreSQL driver NOT found.");
    }
    
    if (str_contains($drivers, 'mysql')) {
        info("✅ MySQL driver found.");
    } else {
        info("❌ MySQL driver NOT found.");
    }

    info("Checking configuration file (.env.local.php) in shared/:");
    $exists = run("if [ -f {{deploy_path}}/shared/.env.local.php ]; then echo 'exists'; else echo 'missing'; fi");
    if ($exists === 'exists') {
        info("✅ .env.local.php found in shared/.");
        
        // Tentative de diagnostic de connexion DB si possible
        info("Checking database connection from .env.local.php...");
        $testDb = run("$php -r \"
            \\\$env = @include '{{deploy_path}}/shared/.env.local.php';
            if (!is_array(\\\$env) || !isset(\\\$env['DATABASE_URL'])) {
                echo 'DATABASE_URL not found in .env.local.php';
                exit;
            }
            \\\$url = \\\$env['DATABASE_URL'];
            \\\$parts = parse_url(\\\$url);
            \\\$host = \\\$parts['host'] ?? '127.0.0.1';
            \\\$port = \\\$parts['port'] ?? 3306;
            
            echo 'Testing connection to ' . \\\$host . ':' . \\\$port . '... ';
            \\\$connection = @fsockopen(\\\$host, \\\$port, \\\$errno, \\\$errstr, 2);
            if (is_resource(\\\$connection)) {
                echo '✅ SUCCESS: Port is open.';
                fclose(\\\$connection);
            } else {
                echo '❌ FAILED: ' . \\\$errstr . ' (' . \\\$errno . ')';
            }
        \"");
        info($testDb);
    } else {
        info("❌ .env.local.php MISSING in shared/! Ensure you have set the DB secrets in GitHub or created the file manually.");
    }
});

// ── Migrations Doctrine ─────────────────────────────────────────
desc('Run Doctrine migrations');
task('deploy:migrate', function () {
    run('cd {{release_path}} && {{bin/php}} bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration --env={{symfony_env}}');
});

// ── Permissions var/ ────────────────────────────────────────────
desc('Fix var/ permissions');
task('deploy:permissions', function () {
    run('chmod -R 775 {{release_path}}/var 2>/dev/null || true');
});

// ── Post-deployment Healthcheck ─────────────────────────────────
desc('Healthcheck after deployment');
task('deploy:healthcheck', function () {
    $url = get('healthcheck_url', '');
    if (empty($url)) {
        info('No healthcheck_url configured, skipping.');
        return;
    }

    $attempts = 5;
    for ($i = 1; $i <= $attempts; $i++) {
        try {
            $result = runLocally("curl -sf --max-time 10 $url");
            info("✅ Healthcheck passed ($url)");
            return;
        } catch (\Exception $e) {
            if ($i === $attempts) {
                throw new \RuntimeException("❌ Healthcheck failed after $attempts attempts: $url");
            }
            info("Attempt $i/$attempts failed, retrying in 10s...");
            sleep(10);
        }
    }
});

// ── Deployment Notification ─────────────────────────────────────
// Optional — notifications are managed by GitHub Actions
// but they can also be sent from Deployer
desc('Notify deployment');
task('deploy:notify', function () {
    $env    = get('labels')['env'] ?? 'unknown';
    $release = basename(get('release_path'));
    info("Deployed release $release to $env");
});

// ════════════════════════════════════════════════════════════════
//  Deployment pipeline scheduling
// ════════════════════════════════════════════════════════════════

/*
 *  Ordre d'exécution :
 *
 *  deploy:info
 *  deploy:setup          ← crée releases/, shared/, current/ si inexistants
 *  deploy:check          ← vérifie drivers PHP et .env.local.php (diagnostic)
 *  deploy:lock           ← verrou anti-déploiement concurrent
 *  deploy:release        ← crée releases/YYYYMMDD_HHMMSS/
 *  deploy:update_code    ← copie le code (depuis CI, pas git clone)
 *  deploy:shared         ← symlinks vers shared/ (.env.local.php, var/log…)
 *  deploy:writable       ← chmod sur var/
 *  deploy:vendors        ← composer install --no-dev --optimize-autoloader
 *  deploy:upload_assets  ← upload public/build/ depuis CI  (custom)
 *  deploy:migrate        ← doctrine:migrations:migrate      (custom)
 *  deploy:permissions    ← chmod var/                       (custom)
 *  deploy:cache:clear    ← bin/console cache:clear          (recipe Symfony)
 *  deploy:cache:warmup   ← bin/console cache:warmup         (recipe Symfony)
 *  deploy:symlink        ← current -> releases/xxx          (atomique ✅)
 *  deploy:unlock         ← libère le verrou
 *  deploy:cleanup        ← supprime les vieilles releases (keep_releases=5)
 *  deploy:healthcheck    ← vérifie que le site répond       (custom)
 *  deploy:notify         ← log de déploiement               (custom)
 *  deploy:success        ← affichage final
 */

after('deploy:setup', 'deploy:secrets');
after('deploy:secrets', 'deploy:check');
after('deploy:vendors', 'deploy:upload_assets');
after('deploy:upload_assets', 'deploy:migrate');
after('deploy:migrate', 'deploy:permissions');
after('deploy:symlink', 'deploy:healthcheck');
after('deploy:healthcheck', 'deploy:notify');

// In case of failure: automatic rollback
after('deploy:failed', 'deploy:unlock');
