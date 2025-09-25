# Dockerized Symfony Project Scaffold 🚀  
*(Makefile-driven bootstrapper for rapid Symfony development)*  

This repository provides an **interactive `make init` wizard** to quickly bootstrap a fully containerized Symfony project.  
It is designed for **developers, teams, and CI pipelines**, supporting flexible configurations:  

- **Web server**: Nginx *(default)* or Apache  
- **Database**: PostgreSQL *(default)* or MySQL  
- **Cache/Session**: Redis *(optional)*  
- **Frontend**: Asset Mapper *(default)* or Webpack Encore (with Node.js)  

Symfony is automatically installed in `./app`.  

---

## 🛠 Requirements  

- Docker Desktop 4.x+  
- Docker Compose V2 (`docker compose`)  
- GNU Make  
- Bash shell (Linux/macOS, or Git Bash/WSL on Windows)  

⚠️ **Windows users:**  
- Run commands inside Git Bash or WSL (not PowerShell/cmd).  
- Hosts file updates may require elevation (PowerShell prompt or manual edit).  

---

## ⚡ Quick Start  

```bash
    make init
```

The initializer will guide you through:  
- **Project name**  
- **Symfony version**: latest stable *(default)*, latest LTS, or custom string  
- **Distribution**: Full *(webapp, default)* or API  
- **Frontend assets**: Asset Mapper *(default)* or Webpack Encore  
- **Web server**: Nginx *(default)* or Apache  
- **Database**: PostgreSQL *(default)* or MySQL  
- **Virtual host name** *(default: localhost)*  
- **Ports**: web, DB, Redis (with conflict detection)  

✅ Result:  
- `.make.local` and `.env` created  
- Symfony installed in `./app`  
- Containers built & started  
- Hosts file updated (if possible)  

Access your app:  
👉 http://<VHOST>:<WEB_PORT>  
*(e.g., http://localhost:8080)*  

---

## 🧰 Common Commands  

| Command | Description |
|---------|-------------|
| `make up / make down / make restart` | Start/stop/restart containers |
| `make ps` | List container status |
| `make logs [SERVICE=php|web|db|redis|node]` | Show logs |
| `make terminal` | Open a shell in the PHP container |
| `make composer ARGS="..."` | Run Composer inside container |
| `make console ARGS="..."` | Run Symfony console |
| `make cache-clear` | Clear Symfony cache |
| `make migrate` | Run Doctrine migrations (or fallback) |
| `make fixtures` | Load fixtures (or DB import) |
| `make assets` | Build assets (Encore or Asset Mapper) |
| `make assets-watch` | Watch assets with Encore |
| `make tests` | Run PHPUnit |
| `make xdebug-on / make xdebug-off` | Toggle Xdebug |
| `make clean` | Remove containers & volumes |
| `make reset` | Full reset (remove `./app` & Node artifacts) |

---

## 🏗 Service Architecture  

```
                ┌───────────────┐
                │   Nginx/Apache│
                │    (web)      │
                └───────▲───────┘
                        │
                        ▼
┌─────────────┐   ┌─────────────┐   ┌──────────┐
│   PHP-FPM   │   │   Database  │   │   Redis  │
│ (Symfony)   │   │ (Postgres/  │   │ (optional│
│  Composer   │   │  MySQL)     │   │  cache)  │
└───────▲─────┘   └──────▲──────┘   └────▲─────┘
        │                │              │
        ▼                │              │
    ┌─────────────┐      │         ┌───────────┐
    │   Node.js   │◄─────┘         │   Browser │
    │ (Encore)    │   Frontend     │  (Client) │
    └─────────────┘   Assets       └───────────┘
```

---

## 📂 Project Structure  

```
.
├── Makefile
├── docker-compose.yml
├── README.md
├── .env                 # Symfony environment variables
├── .make.local          # Saved init config
├── app/                 # Symfony project
└── .docker/
    ├── php/
    │   ├── Dockerfile
    │   └── conf/{php.ini, xdebug.ini}
    ├── web/
    │   ├── nginx/       # Nginx configs/templates
    │   └── apache/      # Apache configs/templates
    └── node/
        └── Dockerfile
```

---

## 🔧 Configuration Files  

- **.env** → Injected into containers (`docker-compose.yml`)  
- **.make.local** → Stores init answers (project slug, DB defaults…)  
- **.docker/** → Service definitions & config templates  

Idempotent behavior:  
- Existing configs are preserved  
- Ports checked before assignment  
- Symfony reused unless reset  

---

## 🎨 Asset Mapper vs Webpack Encore  

- **Asset Mapper** *(default)*: lightweight, modern.  
- **Encore**: automatically selected if Asset Mapper unsupported. Enables `node` profile.  

---

## ⚙️ Environment Variables  

Generated `app/.env.local` includes:  
- `APP_ENV=dev`  
- `APP_DEBUG=1`  
- `APP_URL`  
- `TRUSTED_PROXIES`, `TRUSTED_HOSTS`  
- `DATABASE_URL`  
- `REDIS_URL` (if enabled)  

---

## 🐛 Troubleshooting  

- **Port conflicts** → choose another port, update `.env`, `make restart`  
- **Hosts file not updated** → manually add `127.0.0.1 <vhost>`  
- **Composer memory issues** → increase memory in `.docker/php/conf/php.ini`  
- **Xdebug issues** → check IDE listening on `9003`, toggle with `make xdebug-on`  
- **Windows file permissions** → ensure host user `uid=1000`, or adjust Dockerfile  

---

## 🤖 CI/CD Usage  

- Use `docker compose --profile ... up` to start only required services  
- Composer cache persisted in named volume (`<slug>_composer_cache`) for faster builds  

---

## 📜 License  

MIT License. Free to use, modify, and share.

