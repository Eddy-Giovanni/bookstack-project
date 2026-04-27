# BookStack - Plateforme de Documentation Moderne

## Architecture

┌─────────────────────────────────────────────────────────────┐
│ Utilisateur │
└─────────────────────────┬───────────────────────────────────┘
│ HTTPS
▼
┌─────────────────────────────────────────────────────────────┐
│ Reverse Proxy (Nginx:443) │
│ SSL Termination │
└─────────────────────────┬───────────────────────────────────┘
│
▼
┌─────────────────────────────────────────────────────────────┐
│ BookStack Application │
│ (Port 8080) │
└─────────────────────────┬───────────────────────────────────┘
│
▼
┌─────────────────────────────────────────────────────────────┐
│ mariadb (Port 5432) │
│ Données persistantes │
└─────────────────────────────────────────────────────────────┘


## Prérequis

- Docker Desktop
- Git
- AWS CLI configuré
- OpenSSL

## Installation Rapide

```bash
# 1. Cloner le projet
git clone https://github.com/votre-compte/bookstack-project.git
cd bookstack-project

# 2. Copier et configurer .env
cp config/.env.example .env
# Éditer .env avec vos valeurs

# 3. Générer APP_KEY
openssl rand -base64 32

# 4. Générer les certificats SSL (dev)
cd nginx/ssl
openssl genrsa -out key.pem 2048
openssl req -x509 -new -nodes -key key.pem -sha256 -days 365 -out cert.pem

# 5. Démarrer
make up

# 6. Accéder
https://localhost

Commandes
Commande	Description
make up	Démarrer les services
make down	Arrêter les services
make logs	Voir les logs
make backup	Sauvegarde vers S3
make restore FILE=xxx	Restaurer depuis S3
make clean	Nettoyage complet


Pipeline CI/CD
Le projet utilise GitHub Actions pour :

Build de l'image Docker

Push vers AWS ECR

Déploiement automatique

Sauvegarde
Les backups sont automatiques et stockés dans AWS S3.

Monitoring
Logs: Loki + Grafana (http://localhost:3000)

Healthcheck: http://localhost/health

Sécurité
HTTPS obligatoire

Base de données non exposée

Variables d'environnement pour secrets

Conteneurs non-root


---

### Étape 11 : Création du pipeline CI/CD (GitHub Actions)

**Importance :** Automatise le build et le déploiement.

**Fichier :** `C:\Users\%USERNAME%\bookstack-project\.github\workflows\deploy.yml`

```yaml
name: Build, Push and Deploy BookStack

on:
  push:
    branches:
      - main
      - master
  pull_request:
    branches:
      - main

env:
  AWS_REGION: eu-west-3
  ECR_REPOSITORY: bookstack-app
  IMAGE_TAG: ${{ github.sha }}

jobs:
  # ============================================
  # JOB 1: Build et Push vers ECR
  # ============================================
  build-and-push:
    name: Build and Push to ECR
    runs-on: ubuntu-latest
    if: github.event_name != 'pull_request'

    steps:
      # 1. Récupération du code
      - name: Checkout code
        uses: actions/checkout@v4

      # 2. Configuration AWS
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      # 3. Login à Amazon ECR
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      # 4. Build de l'image
      - name: Build Docker image
        run: |
          docker build -f docker/Dockerfile -t ${{ env.ECR_REPOSITORY }}:${{ env.IMAGE_TAG }} .
          docker build -f docker/Dockerfile -t ${{ env.ECR_REPOSITORY }}:latest .

      # 5. Tag de l'image
      - name: Tag image
        run: |
          docker tag ${{ env.ECR_REPOSITORY }}:${{ env.IMAGE_TAG }} ${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:${{ env.IMAGE_TAG }}
          docker tag ${{ env.ECR_REPOSITORY }}:latest ${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:latest

      # 6. Push vers ECR
      - name: Push image to ECR
        run: |
          docker push ${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:${{ env.IMAGE_TAG }}
          docker push ${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:latest

  # ============================================
  # JOB 2: Tests (si PR)
  # ============================================
  test:
    name: Test Docker build
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Build test
        run: |
          docker build -f docker/Dockerfile -t bookstack-test .
          docker run --rm bookstack-test echo "Build successful"

  # ============================================
  # JOB 3: Déploiement (optionnel)
  # ============================================
  deploy:
    name: Deploy to Server
    runs-on: ubuntu-latest
    needs: build-and-push
    if: github.ref == 'refs/heads/main'

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Deploy via SSH
        uses: appleboy/ssh-action@v0.1.5
        with:
          host: ${{ secrets.DEPLOY_HOST }}
          username: ${{ secrets.DEPLOY_USER }}
          key: ${{ secrets.DEPLOY_SSH_KEY }}
          script: |
            cd /opt/bookstack
            docker-compose pull
            docker-compose up -d --force-recreate
            docker system prune -f

            