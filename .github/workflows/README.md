# Configuration CI/CD (GitHub Actions et GitLab CI)

## GitHub Actions

**Où configurer :** dépôt GitHub → **Settings** → **Secrets and variables** → **Actions**

### Secrets (onglet Secrets)

| Nom | Description | Où le trouver |
|-----|-------------|----------------|
| `AWS_ACCESS_KEY_ID` | Clé d'accès IAM | [AWS Console](https://console.aws.amazon.com/) → **IAM** → **Users** → votre utilisateur → **Security credentials** → **Create access key** |
| `AWS_SECRET_ACCESS_KEY` | Secret associé | Affiché **une seule fois** à la création de la clé |
| `ECR_REGISTRY` | URL du registry ECR (sans `/repo`) | **ECR** → votre repository → **View push commands** → partie avant le nom du repo. Ex. : `123456789012.dkr.ecr.eu-north-1.amazonaws.com` |

### Variables (onglet Variables, optionnel)

| Nom | Exemple | Description |
|-----|---------|-------------|
| `AWS_REGION` | `eu-north-1` | Région AWS (défaut dans le workflow : `eu-north-1`) |
| `ECR_REPOSITORY` | `bookstack-isi4` | Nom du dépôt ECR |

### Secrets optionnels (déploiement EC2)

| Nom | Description |
|-----|-------------|
| `DEPLOY_HOST` | IP ou hostname EC2 |
| `DEPLOY_USER` | `ubuntu`, `ec2-user`, etc. |
| `DEPLOY_SSH_KEY` | Clé privée SSH (.pem) |
| `DEPLOY_PATH` | Répertoire sur le serveur (ex. `/opt/bookstack`) |

**Déclenchement :** push sur `main` / `master`, tag, ou **Actions** → **Build and Push to ECR** → **Run workflow**.

---

## GitLab CI

**Où configurer :** projet GitLab → **Settings** → **CI/CD** → **Variables** → **Add variable**

| Variable | Type | Masked | Protected | Où le trouver |
|----------|------|--------|-----------|----------------|
| `AWS_ACCESS_KEY_ID` | Variable | Oui | Recommandé | IAM → Security credentials |
| `AWS_SECRET_ACCESS_KEY` | Variable | Oui | Recommandé | Création de la clé d'accès |
| `ECR_REGISTRY` | Variable | Non | Non | ECR → View push commands (URI sans nom de repo) |
| `AWS_DEFAULT_REGION` | Variable | Non | Non | Même région que ECR/RDS (ex. `eu-north-1`) |
| `ECR_REPOSITORY` | Variable | Non | Non | Nom du repo ECR (ex. `bookstack-isi4`) |
| `DEPLOY_HOST` | Variable | Non | Oui | Console EC2 → instance → Public IPv4 |
| `DEPLOY_USER` | Variable | Non | Oui | AMI : `ubuntu` (Ubuntu), `ec2-user` (Amazon Linux) |
| `DEPLOY_SSH_KEY` | Variable (File) | Oui | Oui | Paire de clés créée pour EC2 (.pem) |
| `DEPLOY_PATH` | Variable | Non | Non | Chemin du projet sur le serveur |

**Déploiement :** job `deploy:ec2` en **manuel** après un push sur la branche par défaut.

Fichier pipeline : `.gitlab-ci.yml` à la racine du projet.

---

## Variables d'exécution (EC2 / ECS / docker-compose — pas dans le CI)

À configurer dans `.env` sur le serveur ou dans **AWS Secrets Manager** / task definition ECS :

| Variable | Rôle |
|----------|------|
| `APP_URL` | URL publique (ex. `https://votre-domaine.com`) |
| `APP_KEY` | `openssl rand -base64 32` |
| `DB_HOST` | Endpoint RDS (ex. `xxx.rds.amazonaws.com`) |
| `DB_*` | Identifiants base MariaDB/MySQL |
| `BOOKSTACK_SEED_USERS` | `false` en production |

Ces valeurs ne doivent **pas** être commitées dans Git.
