# 🚀 Symfony Stack Docker

**SymfonyStackDocker** est un socle de développement complet pour les projets Symfony, piloté par un assistant interactif via un `Makefile`. Il permet de lancer un projet Symfony containerisé en quelques secondes, avec un environnement de production et de pré-production déjà pensé.

---

## 🌟 Points forts

- **🛠 Assistant Interactif** : Un assistant `make install` vous guide pour configurer le projet (Vhost, DB, Symfony version, etc.).
- **🐳 Multi-Stack Docker** :
    - Serveur Web au choix : **Nginx** ou **Apache**.
    - Base de données au choix : **MariaDB** ou **PostgreSQL**.
    - Support optionnel de **Redis**.
- **📦 Gestion d'Assets** : Support natif de **Asset Mapper** (moderne) ou **Webpack Encore** (classique).
- **✅ Qualité du code** : Outillage pré-configuré (PHPStan, PHP-CS-Fixer, PHPUnit, TwigCS).
- **🔎 Debugging complet** : Mailpit pour les emails, phpMyAdmin (si MariaDB), Xdebug prêt à l'emploi.
- **🚀 Déploiement prêt** : Scripts de déploiement et arborescence de production standardisée.

---

## 📋 Pré-requis

- **Docker** & **Docker Compose** V2
- **GNU Make**
- **Git Bash** (recommandé pour Windows) ou WSL

> ⚠️ **Utilisateurs Windows** : Exécutez toutes les commandes dans un terminal Git Bash ou WSL.

---

## ⚙️ Installation Rapide

1. **Cloner le dépôt** :
   ```bash
   git clone https://github.com/Engrev/SymfonyStackDocker.git mon-projet
   cd mon-projet
   ```

2. **Lancer l'assistant d'installation** :
   ```bash
   make install
   ```
   L'assistant va :
   - Vérifier votre installation Docker.
   - Vous poser des questions sur votre configuration (nom du projet, version Symfony, type de DB, etc.).
   - Construire les images Docker et démarrer les conteneurs.
   - Installer une nouvelle application Symfony dans le dossier `/app`.
   - Installer toutes les dépendances de développement.
   - Tenter d'ajouter votre domaine (ex: `symfony.local`) à votre fichier `hosts`.

![installation](../screenshots/install.png)

---

## 🧰 Commandes Essentielles (Makefile)

### 🐳 Docker & Infrastructure
| Commande | Description |
| :--- | :--- |
| `make up` | Démarre les conteneurs en arrière-plan. |
| `make down` | Arrête et supprime les conteneurs. |
| `make restart` | Redémarrage complet (down + up). |
| `make ps` | Affiche l'état des conteneurs. |
| `make logs` | Affiche les logs de tous les services. |
| `make terminal-php` | Entre dans le conteneur PHP (utilisateur `www-data`). |

### 🎼 Symfony & Composer
| Commande | Description |
| :--- | :--- |
| `make console ARGS="..."` | Exécute une commande de la console Symfony. |
| `make composer ARGS="..."` | Exécute une commande Composer. |
| `make cc` | Vide le cache de l'application. |

### 🗄️ Base de données
| Commande | Description |
| :--- | :--- |
| `make db-migrate` | Exécute les migrations Doctrine. |
| `make db-fixtures` | Charge les jeux de données (fixtures). |
| `make db-reset` | Réinitialise la base (Drop, Create, Migrate). |
| `make db-dump` | Crée un export SQL dans `var/dump.sql`. |
| `make db-import` | Importe `var/dump.sql` (ou spécifié via `ARGS`). |

### 🧪 Qualité & Tests
| Commande | Description |
| :--- | :--- |
| `make tests` | Lance la suite complète (Linters, PHPStan, PHPUnit). |
| `make phpstan` | Analyse statique du code. |
| `make php-cs-fixer` | Corrige automatiquement les standards de codage. |
| `make phpunit` | Lance les tests unitaires et fonctionnels. |

---

## 🏗 Structure du Projet

```text
.
├── .docker/                # Configuration Docker (PHP, Web, Node, etc.)
├── app/                    # 📂 Code source Symfony (généré à l'install)
│   ├── src/                # Vos contrôleurs, entités, services...
│   ├── templates/          # Vues Twig
│   ├── public/             # Point d'entrée Web
│   └── tests/              # Tests automatisés
├── makefiles/              # Scripts modulaires du Makefile
├── docker-compose.yml      # Orchestration Docker
├── Makefile                # Point d'entrée de l'automatisation
└── .env.docker             # Variables d'environnement Docker
```

---

## 🔍 Debugging & Outils

- **Mailpit** : Interception des emails envoyés par l'app.
  - Access : `http://<vhost>:8025`
- **phpMyAdmin** : Gestion DB (si MariaDB).
  - Access : `http://<vhost>:<port_configuré>` (par défaut 8081).
- **Xdebug** : Déjà installé, désactivé par défaut.
  - `make xdebug-on` / `make xdebug-off`
- **Redis** : Support optionnel.
  - `make redis-on` / `make redis-off`

---

## 🚀 Déploiement

Le projet est conçu pour un déploiement sécurisé et professionnel :
1. **Arborescence Serveur** : Utilisation d'un système de `releases/` et de liens symboliques (`current/`) pour des déploiements sans interruption.
2. **Scripts inclus** : `activate_release.sh` et `rollback.sh` pour automatiser la mise en production.
3. **GitHub Actions** : Workflow prêt pour déployer via SSH avec des clés de déploiement.

Consultez le fichier [**DEPLOYING.md**](DEPLOYING.md) pour le guide détaillé étape par étape de la mise en production.

---

## 🧹 Nettoyage & Réinitialisation

- `make reset` : Supprime le dossier `/app`, les configurations générées et les conteneurs. Permet de repartir de zéro avec `make install`.

---

## 📄 Licence

Ce projet est sous licence MIT. Libre à vous de l'utiliser et de le modifier.

---
*Réalisé avec ❤️ pour simplifier le développement Symfony.*
