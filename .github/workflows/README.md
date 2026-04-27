# Configuration des GitHub Secrets

Pour que le pipeline CI/CD fonctionne, vous devez configurer ces secrets dans GitHub :

## Étapes de configuration

1. Allez sur votre repository GitHub
2. Cliquez sur **Settings** (onglet en haut)
3. Dans le menu gauche : **Secrets and variables** → **Actions**
4. Cliquez sur **New repository secret**
5. Ajoutez les 3 secrets suivants :

## Secrets requis

### 1. AWS_ACCESS_KEY_ID
- **Nom** : `AWS_ACCESS_KEY_ID`
- **Valeur** : Votre Access Key ID AWS (commence par `AKIA...`)
- **Comment l'obtenir** : AWS Console → IAM → Users → Security credentials → Create access key

### 2. AWS_SECRET_ACCESS_KEY
- **Nom** : `AWS_SECRET_ACCESS_KEY`
- **Valeur** : Votre Secret Access Key AWS (longue chaîne alphanumérique)
- **Comment l'obtenir** : Affiché une seule fois lors de la création de l'Access Key

### 3. ECR_REGISTRY
- **Nom** : `ECR_REGISTRY`
- **Valeur** : `288720720990.dkr.ecr.us-east-1.amazonaws.com`
- **Comment l'obtenir** : C'est la partie avant le `/` dans le repositoryUri

## Vérification

Une fois les secrets configurés, le pipeline se déclenchera automatiquement à chaque push sur `main` ou `master`.

Vous pouvez aussi le déclencher manuellement :
- GitHub → Actions → "Build and Push to ECR" → Run workflow
