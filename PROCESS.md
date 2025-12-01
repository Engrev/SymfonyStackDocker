# PROCESS

## Création du projet

1. Initialisation du projet (symfony new).
2. Envoyer le projet sur github.
3. Créer la branche **release** depuis **main**.

## Sur le serveur

### SSH

4. Créer un utilisateur ssh sur le serveur pour le déploiement.
5. Générer une clé ssh pour cet utilisateur : `ssh-keygen -t ed25519 -C "github-deploy"`.
6. Récupérer cette clé (publique) : `cat ~/.ssh/id_ed25519.pub`.
7. L'ajouter au projet sur github : Settings → Deploy Keys → Add deploy key.
8. Tester la connexion ssh : `ssh -i ~/.ssh/id_ed25519 -T git@github.com`.
   👉 Si tout est bon, tu devrais voir un message du genre :
   ***Hi <username>! You've successfully authenticated, but GitHub does not provide shell access.***
9. On simplifie l’utilisation de la clé, en disant à SSH “quand je parle à github.com, utilise cette clé” : `nano ~/.ssh/config`.
```
Host github.com
  HostName github.com
  User git
  IdentityFile /home/<user>/.ssh/id_ed25519
  IdentitiesOnly yes
```

### Arborescence

10. Créer l’arborescence projet :
```
/var/www/
├── project_name/
│   ├── prod/
│   │   ├── current -> releases/YYYYMMDD-Hi2/
│   │   ├── releases/
│   │   │   ├── YYYYMMDD-Hi2/
│   │   │   └── YYYYMMDD-Hi1/
│   │   └── shared/   # logs, cache, sessions, uploads, .env.local
│   └── pprod/
│       ├── current -> releases/YYYYMMDD-Hi2/
│       ├── releases/
│       │   ├── YYYYMMDD-Hi2/
│       │   └── YYYYMMDD-Hi1/
│       └── shared/
```
Avec ces commandes :
```bash
  mkdir -p /var/www/<project_name>/bin
  mkdir -p /var/www/<project_name>/pprod/{releases,shared}
  mkdir -p /var/www/<project_name>/prod/{releases,shared}
```

### Installation du projet

11. Cloner le projet dans releases/ avec le timestamp :
```bash
  cd /var/www/<project_name>/pprod/releases
  git clone git@github.com:<User>/<ProjectName>.git YYYYMMDD-Hi
```
12. Installer les dépendances :
```bash
  composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist --classmap-authoritative
  php bin/console cache:clear --env=prod
  php bin/console doctrine:migrations:migrate --no-interaction --env=prod
```
13. Lier les dossiers partagés :
```bash
  ln -sfn /var/www/<project_name>/pprod/releases/YYYYMMDD-Hi /var/www/<project_name>/pprod/current
  mv /var/www/<project_name>/pprod/releases/YYYYMMDD-Hi/.env /var/www/<project_name>/pprod/shared/.env
  ln -sfn /var/www/<project_name>/pprod/shared/.env /var/www/<project_name>/pprod/current/.env
  
  mkdir -p /var/www/<project_name>/pprod/shared/var/log
  ln -sfn /var/www/<project_name>/pprod/shared/var/log /var/www/<project_name>/pprod/current/var/log
  
  mkdir -p /var/www/<project_name>/pprod/shared/public/uploads
  ln -sfn /var/www/<project_name>/pprod/shared/public/uploads /var/www/<project_name>/pprod/current/public/uploads
```
14. Copier les scripts [**activate_release.sh**](.docker/github/bin/activate_release.sh) et [**rollback.sh**](.docker/github/bin/rollback.sh) dans **/var/www/<project_name>/bin/**.
15. Les rendre exécutables : `chmod +x /var/www/<project_name>/bin/*.sh`.
Exemples d'utilisation des scripts :
```
  /var/www/<project_name>/bin/activate_release.sh <prod|pprod> <release-name>
  /var/www/<project_name>/bin/rollback.sh <prod|pprod>
```

## Sur Github

### Secrets GitHub à créer (Settings → Secrets and variables → Actions)

| Clé                 | Description |
|---------------------|-------------|
| DEPLOY_KEY          | clé privée (format PEM) qui a été générée pour GitHub → server |
| SSH_HOST            | IP ou hostname du serveur |
| SSH_USER            | deploy (utilisateur créé à l'étape 4) |
| APP_PATH            | /var/www/<project_name> (chemin root utilisé dans scripts) |
| SMTP_*              | pour envoi d’email |
| MAIL_TO / MAIL_FROM | destinataire & expéditeur des notifications |


Créer le sous-domaine/domaine pour le projet sur le serveur et définir le chemin des fichiers sur **/var/www/<project_name>/<pprod|prod>/current/public/**.
