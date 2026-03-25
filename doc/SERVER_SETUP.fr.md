# Configuration du serveur distant pour Deployer

> **À faire une seule fois** avant le premier déploiement.

---

## 1. Créer l'utilisateur de déploiement

Sur un serveur dédié ou VPS, créez un utilisateur dédié au déploiement. Sur un serveur mutualisé, cet utilisateur existe déjà — passez à l'étape suivante.

```bash
useradd -m -s /bin/bash deployer
```

---

## 2. Configurer la clé SSH

### Générer une paire de clés ed25519 en local

```bash
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/deploy_key
```

Cela génère deux fichiers :
- `~/.ssh/deploy_key` — clé **privée** (à ajouter dans GitHub)
- `~/.ssh/deploy_key.pub` — clé **publique** (à déposer sur le serveur)

### Copier la clé publique sur le serveur

```bash
ssh-copy-id -i ~/.ssh/deploy_key.pub deployer@votre-serveur.com
```

### Ajouter la clé privée dans GitHub

`Settings → Secrets and variables → Actions → New repository secret`

| Nom | Valeur |
|-----|--------|
| `DEPLOY_KEY` | Contenu du fichier `~/.ssh/deploy_key` |

---

## 3. Créer la structure des dossiers

Remplacez `APP_BASE` par votre chemin réel sur le serveur.

```bash
APP_BASE="/home/clients/xxx/sites/mon-projet"

# Production
mkdir -p "$APP_BASE/prod/releases"
mkdir -p "$APP_BASE/prod/shared/var/log"
mkdir -p "$APP_BASE/prod/shared/var/sessions"
mkdir -p "$APP_BASE/prod/shared/public/uploads"

# Pré-production
mkdir -p "$APP_BASE/pprod/releases"
mkdir -p "$APP_BASE/pprod/shared/var/log"
mkdir -p "$APP_BASE/pprod/shared/var/sessions"
mkdir -p "$APP_BASE/pprod/shared/public/uploads"
```

Deployer créera automatiquement le symlink `current/` lors du premier déploiement.

```
mon-projet/
├── prod/
│   ├── releases/
│   │   ├── 20250311_143000/
│   │   └── 20250310_091500/
│   ├── current -> releases/20250311_143000   ← symlink géré par Deployer
│   └── shared/
│       ├── .env.local
│       ├── var/log/
│       ├── var/sessions/
│       └── public/uploads/
└── pprod/
    └── (même structure)
```

---

## 4. Créer les fichiers `.env.local` sur le serveur

> ⚠️ Ces fichiers contiennent les **vrais credentials**. Ils ne doivent jamais être versionnés dans Git.

### Production

```bash
cat > "$APP_BASE/prod/shared/.env.local" <<'ENV'
APP_SECRET=votre_secret_prod_ici
DATABASE_URL=mysql://user:password@localhost:3306/db_prod?serverVersion=11.8.6-MariaDB&charset=utf8mb4
MAILER_DSN=smtp://user:pass@smtp.server.com:587
# ... autres variables sensibles
ENV
```

### Pré-production

```bash
cat > "$APP_BASE/pprod/shared/.env.local" <<'ENV'
APP_SECRET=votre_secret_pprod_ici
DATABASE_URL=mysql://user:password@localhost:3306/db_pprod?serverVersion=11.8.6-MariaDB&charset=utf8mb4
MAILER_DSN=smtp://user:pass@smtp.server.com:587
ENV
```

---

## 5. Configuration du serveur web (Nginx)

> Le `root` pointe vers `current/public` — **ce chemin ne change jamais** après chaque déploiement. Deployer gère le symlink `current/` de façon transparente.

### Production — `/etc/nginx/sites-available/mon-projet-prod`

```nginx
server {
    listen 443 ssl;
    server_name mon-projet.com;

    root /home/clients/xxx/sites/mon-projet/prod/current/public;

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

### Pré-production — `/etc/nginx/sites-available/mon-projet-pprod`

Même configuration, en remplaçant :
- `server_name` par `pprod.mon-projet.com`
- le chemin `prod/` par `pprod/`

---

## 6. Variables GitHub Actions

### Secrets — `Settings → Secrets and variables → Actions → Secrets`

| Nom | Description | Exemple |
|-----|-------------|---------|
| `DEPLOY_KEY` | Clé SSH privée ed25519 | Contenu de `~/.ssh/deploy_key` |
| `DEPLOY_HOST` | Hôte SSH du serveur | `votre-serveur.com` |
| `DEPLOY_USER` | Utilisateur SSH | `deployer` |
| `DEPLOY_BASE_PATH` | Chemin de base sur le serveur | `/home/clients/xxx/sites/mon-projet` |
| `SMTP_SERVER` | Serveur SMTP | `smtp.server.com` |
| `SMTP_PORT` | Port SMTP | `587` |
| `SMTP_USERNAME` | Identifiant SMTP | `user@server.com` |
| `SMTP_PASSWORD` | Mot de passe SMTP | `xxx` |

### Variables — `Settings → Secrets and variables → Actions → Variables`

| Nom | Description | Exemple |
|-----|-------------|---------|
| `MAIL_TO` | Destinataire des notifications | `team@mon-projet.com` |
| `MAIL_FROM` | Expéditeur des notifications | `ci@mon-projet.com` |
| `DOMAIN_PROD` | Domaine de production | `mon-projet.com` |
| `DOMAIN_PPROD` | Domaine de pré-production | `pprod.mon-projet.com` |
| `SERVER_PHP_BIN` | Chemin PHP sur le serveur | `/opt/php8.4/bin/php` |
| `SERVER_COMPOSER_BIN` | Chemin Composer sur le serveur | `/opt/php8.4/bin/composer2.phar` |

---

## 7. Configurer les environnements GitHub

### Production — approbation manuelle obligatoire

`Settings → Environments → New environment → "production"`

- Cochez **Required reviewers**
- Ajoutez votre compte (ou celui du lead tech)
- Tout déploiement vers la production sera mis en attente jusqu'à approbation explicite

### Pré-production — déploiement automatique

`Settings → Environments → New environment → "preproduction"`

- Aucun reviewer requis
- Le déploiement se déclenche automatiquement après un push sur `release`

---

## 8. Vérifier la connexion SSH

Avant le premier déploiement, testez la connexion SSH depuis votre container CI en local :

```bash
# Démarrer le container CI
make ci-up

# Tester la connexion SSH
docker compose -f docker-compose.ci.yml exec php \
    ssh -i ~/.ssh/id_ed25519 deployer@votre-serveur.com "echo OK"
```

Si la commande retourne `OK`, la configuration est correcte.

---

## Récapitulatif des étapes

| Étape | Action | Où |
|-------|--------|----|
| 1 | Créer l'utilisateur `deployer` | Serveur |
| 2 | Générer et déposer la clé SSH | Local + Serveur + GitHub |
| 3 | Créer la structure des dossiers | Serveur |
| 4 | Créer les `.env.local` | Serveur |
| 5 | Configurer Nginx | Serveur |
| 6 | Ajouter secrets et variables | GitHub |
| 7 | Configurer les environnements GitHub | GitHub |
| 8 | Vérifier la connexion SSH | Local |
