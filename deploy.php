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
 *                .env.local         ← to be created manually once
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

require 'vendor/autoload.php';

use Deployer\Exception\RunException;

// ── Official Symfony Recipe ─────────────────────────────────────
require 'vendor/deployer/deployer/recipe/symfony.php';

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
    '.env.local',
]);

// Shared dossiers across all releases
set('shared_dirs', [
    'var/log',
    'var/sessions',
    'public/uploads',
]);

// Directories with write permissions for the web process
set('writable_dirs', [
    'var/cache',
    'var/log',
    'var/sessions',
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

// ════════════════════════════════════════════════════════════════
//  Hosts
// ════════════════════════════════════════════════════════════════

$deployHost  = getenv('DEPLOY_HOST')      ?: 'votre-serveur.com';
$deployUser  = getenv('DEPLOY_USER')      ?: 'deployer';
$deployBase  = getenv('DEPLOY_BASE_PATH') ?: '/home/clients/xxx/sites/mon-projet';

host('pprod')
    ->setHostname($deployHost)
    ->setRemoteUser($deployUser)
    ->setIdentityFile('~/.ssh/id_ed25519')
    ->set('deploy_path', $deployBase . '/pprod')
    ->set('symfony_env', 'prod')      // Symfony runs in prod even in pprod
    ->set('branch', 'release')        // Deployed from the release branch
    ->set('labels', ['env' => 'pprod']);

host('prod')
    ->setHostname($deployHost)
    ->setRemoteUser($deployUser)
    ->setIdentityFile('~/.ssh/id_ed25519')
    ->set('deploy_path', $deployBase . '/prod')
    ->set('symfony_env', 'prod')
    ->set('branch', 'main')           // Deployed from the main branch
    ->set('labels', ['env' => 'prod']);

// ════════════════════════════════════════════════════════════════
//  Custom tasks
// ════════════════════════════════════════════════════════════════

// ── Upload of compiled assets in CI ─────────────────────────────
// The assets are built in CI and uploaded via rsync
// We do NOT build on the server (no Node required)
desc('Upload compiled assets to release');
task('deploy:upload_assets', function () {
    $localAssets = 'public/build/';
    if (!is_dir($localAssets)) {
        info('No compiled assets found in public/build/, skipping upload.');
        return;
    }
    upload($localAssets, '{{release_path}}/public/build/');
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
//  Healthcheck URLs par environnement
// ════════════════════════════════════════════════════════════════

// Enter the healthcheck URLs (endpoint to be created in Symfony)
// Route: /health → returns 200 OK
localhost('pprod')->set('healthcheck_url', getenv('HEALTHCHECK_URL_PPROD') ?: '');
localhost('prod')->set('healthcheck_url', getenv('HEALTHCHECK_URL_PROD') ?: '');

// ════════════════════════════════════════════════════════════════
//  Deployment pipeline scheduling
// ════════════════════════════════════════════════════════════════

/*
 *  Ordre d'exécution :
 *
 *  deploy:info
 *  deploy:setup          ← crée releases/, shared/, current/ si inexistants
 *  deploy:lock           ← verrou anti-déploiement concurrent
 *  deploy:release        ← crée releases/YYYYMMDD_HHMMSS/
 *  deploy:update_code    ← copie le code (depuis CI, pas git clone)
 *  deploy:shared         ← symlinks vers shared/ (.env.local, var/log…)
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

after('deploy:vendors',     'deploy:upload_assets');
after('deploy:upload_assets', 'deploy:migrate');
after('deploy:migrate',     'deploy:permissions');
after('deploy:symlink',     'deploy:healthcheck');
after('deploy:healthcheck', 'deploy:notify');

// In case of failure: automatic rollback
after('deploy:failed',      'deploy:unlock');
