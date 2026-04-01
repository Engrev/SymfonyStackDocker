# Remote Server Setup for Deployer

> **One-time setup** required before the first deployment.

---

## 1. Create the deployment user

On a dedicated server or VPS, create a dedicated deployment user. On shared hosting, this user already exists — skip to the next step.

```bash
useradd -m -s /bin/bash deployer
```

---

## 2. Configure the SSH key

### Generate an ed25519 key pair locally

```bash
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/deploy_key
```

This generates two files:
- `~/.ssh/deploy_key` — **private** key (to add to GitHub)
- `~/.ssh/deploy_key.pub` — **public** key (to deploy on the server)

### Copy the public key to the server

```bash
ssh-copy-id -i ~/.ssh/deploy_key.pub deployer@your-server.com
```

### Add the private key to GitHub

`Settings → Secrets and variables → Actions → New repository secret`

| Name | Value |
|------|-------|
| `DEPLOY_KEY` | Contents of `~/.ssh/deploy_key` |

---

## 3. Create the directory structure

Replace `APP_BASE` with your actual path on the server.

```bash
APP_BASE="/home/clients/xxx/sites/my-project"

# Production
mkdir -p "$APP_BASE/prod/releases"
mkdir -p "$APP_BASE/prod/shared/var/log"
mkdir -p "$APP_BASE/prod/shared/var/sessions"
mkdir -p "$APP_BASE/prod/shared/public/uploads"

# Pre-production
mkdir -p "$APP_BASE/pprod/releases"
mkdir -p "$APP_BASE/pprod/shared/var/log"
mkdir -p "$APP_BASE/pprod/shared/var/sessions"
mkdir -p "$APP_BASE/pprod/shared/public/uploads"
```

Deployer will automatically create the `current/` symlink on the first deployment.

```
my-project/
├── prod/
│   ├── releases/
│   │   ├── 20250311_143000/
│   │   └── 20250310_091500/
│   ├── current -> releases/20250311_143000   ← symlink managed by Deployer
│   └── shared/
│       ├── .env.local.php
│       ├── var/log/
│       ├── var/sessions/
│       └── public/uploads/
└── pprod/
    └── (same structure)
```

---

## 4. Manage the `.env.local.php` file on the server

> ⚠️ This file contains **real credentials**. It must never be committed to Git.
> Note: Symfony recommends using a PHP file for better performance in production (generated via `composer dump-env prod`).

### Option A: Automatic generation via GitHub Secrets (Recommended)

The deployment pipeline is configured to automatically generate this file from secrets defined in GitHub (see step 6). This avoids manual file handling on the server.

### Option B: Manual creation on the server

If you do not define database secrets in GitHub, you must create the file manually:

#### Production

```bash
# Example content for .env.local.php (must return an array)
cat > "$APP_BASE/prod/shared/.env.local.php" <<'PHP'
<?php

return [
    'APP_ENV' => 'prod',
    'APP_SECRET' => 'your_prod_secret_here',
    'DATABASE_URL' => 'mysql://user:password@localhost:3306/db_prod?serverVersion=11.8.6-MariaDB&charset=utf8mb4',
    'MAILER_DSN' => 'smtp://user:pass@smtp.server.com:587',
];
PHP
```

#### Pre-production

```bash
cat > "$APP_BASE/pprod/shared/.env.local.php" <<'PHP'
<?php

return [
    'APP_ENV' => 'prod',
    'APP_SECRET' => 'your_pprod_secret_here',
    'DATABASE_URL' => 'mysql://user:password@localhost:3306/db_pprod?serverVersion=11.8.6-MariaDB&charset=utf8mb4',
    'MAILER_DSN' => 'smtp://user:pass@smtp.server.com:587',
];
PHP
```

---

## 5. Web server configuration (Nginx)

> The `root` points to `current/public` — **this path never changes** between deployments. Deployer manages the `current/` symlink transparently.

### Production — `/etc/nginx/sites-available/my-project-prod`

```nginx
server {
    listen 443 ssl;
    server_name my-project.com;

    root /home/clients/xxx/sites/my-project/prod/current/public;

    index index.php;

    location / {
        try_files $uri /index.php$is_args$args;
    }

    location ~ ^/index\.php(/|$) {
        fastcgi_pass unix:/run/php/php8.4-fpm.sock;
        fastcgi_split_path_info ^(.+\.php)(/.*)$;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT $realpath_root;
        internal;
    }

    location ~ \.php$ { return 404; }
}
```

### Pre-production — `/etc/nginx/sites-available/my-project-pprod`

Same configuration, replacing:
- `server_name` with `pprod.my-project.com`
- the `prod/` path with `pprod/`

---

## 6. GitHub Actions variables

### Secrets — `Settings → Secrets and variables → Actions → Secrets`

| Name | Description | Example |
|------|-------------|---------|
| `DEPLOY_KEY` | Private ed25519 SSH key | Contents of `~/.ssh/deploy_key` |
| `DEPLOY_HOST` | Server SSH host | `your-server.com` |
| `DEPLOY_USER` | SSH user | `deployer` |
| `DEPLOY_BASE_PATH` | Base path on the server | `/home/clients/xxx/sites/my-project` |
| `SMTP_SERVER` | SMTP server | `smtp.server.com` |
| `SMTP_PORT` | SMTP port | `587` |
| `SMTP_USERNAME` | SMTP username | `user@server.com` |
| `SMTP_PASSWORD` | SMTP password | `xxx` |
| `DB_HOST` | Database host | `127.0.0.1` |
| `DB_PORT` | Database port | `3306` |
| `DB_NAME` | Database name | `my_app_db` |
| `DB_USER` | Database user | `my_app_user` |
| `DB_PASSWORD` | Database password | `my_secret_db` |
| `APP_SECRET` | Symfony secret (optional) | `a8f9...` |

### Variables — `Settings → Secrets and variables → Actions → Variables`

| Name | Description | Example |
|------|-------------|---------|
| `MAIL_TO` | Notification recipient | `team@my-project.com` |
| `MAIL_FROM` | Notification sender | `ci@my-project.com` |
| `DOMAIN_PROD` | Production domain | `my-project.com` |
| `DOMAIN_PPROD` | Pre-production domain | `pprod.my-project.com` |
| `SERVER_PHP_BIN` | PHP path on the server | `/opt/php8.4/bin/php` |
| `SERVER_COMPOSER_BIN` | Composer path on the server | `/opt/php8.4/bin/composer2.phar` |

---

## 7. Configure GitHub Environments

### Production — mandatory manual approval

`Settings → Environments → New environment → "production"`

- Check **Required reviewers**
- Add your account (or the lead developer's)
- Every production deployment will be held until explicitly approved

### Pre-production — automatic deployment

`Settings → Environments → New environment → "preproduction"`

- No reviewers required
- Deployment triggers automatically after a push to `release`

---

## 8. Verify the SSH connection

Before the first deployment, test the SSH connection from your CI container locally:

```bash
# Start the CI container
make ci-up

# Test the SSH connection
docker compose -f docker-compose.ci.yml exec php \
    ssh -i ~/.ssh/id_ed25519 deployer@your-server.com "echo OK"
```

If the command returns `OK`, the configuration is correct.

---

## Setup checklist

| Step | Action | Where |
|------|--------|-------|
| 1 | Create `deployer` user | Server |
| 2 | Generate and deploy the SSH key | Local + Server + GitHub |
| 3 | Create the directory structure | Server |
| 4 | Create the `.env.local.php` | Server |
| 5 | Configure Nginx | Server |
| 6 | Add secrets and variables | GitHub |
| 7 | Configure GitHub Environments | GitHub |
| 8 | Verify the SSH connection | Local |
