# PROCESS

## Création du projet

1. Cloner [SymfonyStackDocker](https://github.com/Engrev/SymfonyStackDocker).
2. Installer le projet : `make install`.
3. Envoyer le projet sur github : `git init` et terminer avec Github Desktop par exemple.
4. Créer la branche **release** depuis **main**.

## Sur le serveur

### SSH

5. Créer un utilisateur ssh sur le serveur pour le déploiement.
6. Générer une clé ssh pour cet utilisateur : `ssh-keygen -t ed25519 -C "github-deploy"`.
7. Récupérer cette clé (publique) : `cat ~/.ssh/id_ed25519.pub`.
8. L'ajouter au projet sur github : Settings → Deploy Keys → Add deploy key.
9. Tester la connexion ssh : `ssh -i ~/.ssh/id_ed25519 -T git@github.com`.
   👉 Si tout est bon, tu devrais voir un message du genre :
   ***Hi <username>! You've successfully authenticated, but GitHub does not provide shell access.***
10. On simplifie l’utilisation de la clé, en disant à SSH “quand je parle à github.com, utilise cette clé” : `nano ~/.ssh/config`.
```
Host github.com
  HostName github.com
  User git
  IdentityFile /home/<user>/.ssh/id_ed25519
  IdentitiesOnly yes
```
Il faut également l'ajouter dans **/home/\<user>/.ssh/authorized_keys**.

### Arborescence

11. Créer l’arborescence projet :
```
/var/www/
├── project_name/
│   ├── prod/
│   │   ├── current -> releases/YYYYMMDD_Hi2/
│   │   ├── releases/
│   │   │   ├── YYYYMMDD_Hi2/
│   │   │   └── YYYYMMDD_Hi1/
│   │   └── shared/   # logs, cache, sessions, uploads, .env.local
│   └── pprod/
│       ├── current -> releases/YYYYMMDD_Hi2/
│       ├── releases/
│       │   ├── YYYYMMDD_Hi2/
│       │   └── YYYYMMDD_Hi1/
│       └── shared/
```
Avec ces commandes :
```bash
  mkdir -p /var/www/<project_name>/bin
  mkdir -p /var/www/<project_name>/pprod/{releases,shared}
  mkdir -p /var/www/<project_name>/prod/{releases,shared}
```

### Installation du projet

12. Cloner le projet dans releases/ avec le timestamp :
```bash
  cd /var/www/<project_name>/pprod/releases
  git clone -b <branch> git@github.com:<User>/<ProjectName>.git YYYYMMDD_Hi # branch = release pour pprod, main pour prod
```
13. Installer les dépendances et liaison des fichiers/dossiers partagés :
```bash
  cd /var/www/<project_name>/pprod/releases/YYYYMMDD_Hi
  composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist --classmap-authoritative
  php bin/console cache:clear --env=prod
  composer dump-env prod
  mv .env.local.php ../../shared/.env
  # Modifier le .env avec les bonnes valeurs
  # Pour générer un APP_SECRET : openssl rand -hex 32
  ln -sfn ../../shared/.env ./.env.local
  #php bin/console doctrine:migrations:migrate --no-interaction --env=prod
  ln -sfn /var/www/<project_name>/pprod/releases/YYYYMMDD_Hi /var/www/<project_name>/pprod/current

  mkdir -p /var/www/<project_name>/pprod/shared/var/log
  rm -rf /var/www/<project_name>/pprod/current/var/log
  ln -sfn /var/www/<project_name>/pprod/shared/var/log /var/www/<project_name>/pprod/current/var/log
  
  mkdir -p /var/www/<project_name>/pprod/shared/public/uploads
  ln -sfn /var/www/<project_name>/pprod/shared/public/uploads /var/www/<project_name>/pprod/current/public/uploads

  php bin/console importmap:install
  php bin/console asset-map:compile
```
14. Copier les scripts [**activate_release.sh**](.docker/bin/activate_release.sh) et [**rollback.sh**](.docker/bin/rollback.sh) dans **/var/www/<project_name>/bin/**.
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

## Sur l'hébergeur

16. Créer le sous-domaine/domaine pour le projet et définir le chemin des fichiers sur **/<dossier_du_projet>/current/public/**.
17. Si le serveur fonctionne sous apache et qu'apache n'est pas défini en tant que webserver lors de l'installation du projet (en local), rajouter le [**.htaccess**](.docker/.htaccess).
18. Tester d'accéder à votre sous-domaine/domaine.
