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
```


# ***Gestion des Utilisateurs BookStack***

Cette section décrit toutes les opérations CRUD (Create, Read, Update, Delete) sur les utilisateurs BookStack.

## Prérequis

Les commandes doivent être exécutées depuis le répertoire du projet où se trouve `docker-compose.yml`.


## READ - Lister les utilisateurs

### Via la base de données (méthode recommandée)

```bash
docker exec bookstack-db mysql -u bookstack_user -pbookstack_password_123 bookstack -e "SELECT id, name, email, created_at, updated_at FROM users;"
```

### Lister uniquement les emails

```bash
docker exec bookstack-db mysql -u bookstack_user -pbookstack_password_123 bookstack -e "SELECT email FROM users;"
```

### Afficher un utilisateur spécifique

```bash
docker exec bookstack-db mysql -u bookstack_user -pbookstack_password_123 bookstack -e "SELECT * FROM users WHERE email='nguetsamiguel@gmail.com';"
```

### Compter le nombre d'utilisateurs

```bash
docker exec bookstack-db mysql -u bookstack_user -pbookstack_password_123 bookstack -e "SELECT COUNT(*) as total_users FROM users;"
```

---

## CREATE - Créer un utilisateur

### Créer un utilisateur admin

```bash
docker exec bookstack-app php /app/www/artisan bookstack:create-admin \
  --email="nouvel.admin@example.com" \
  --name="Nom Prénom" \
  --password="motdepasse123"
```

**Exemple :**
```bash
docker exec bookstack-app php /app/www/artisan bookstack:create-admin \
  --email="nguetsamiguel@gmail.com" \
  --name="Miguel Nguetsa" \
  --password="azerty12"
```

### Créer un utilisateur via SQL (utilisateur normal, non-admin)

```bash
docker exec bookstack-db mysql -u bookstack_user -pbookstack_password_123 bookstack -e "
INSERT INTO users (name, email, password, created_at, updated_at) 
VALUES ('Jean Dupont', 'jean.dupont@example.com', '\$2y\$10\$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', NOW(), NOW());
"
```

**Note :** Le mot de passe ci-dessus est `password` hashé. Pour un vrai mot de passe, utilisez la commande artisan.

---

##  UPDATE - Modifier un utilisateur

### Changer l'email d'un utilisateur

```bash
docker exec bookstack-db mysql -u bookstack_user -pbookstack_password_123 bookstack -e "
UPDATE users SET email='nouveau.email@example.com', updated_at=NOW() WHERE email='ancien.email@example.com';
"
```

**Exemple :**
```bash
docker exec bookstack-db mysql -u bookstack_user -pbookstack_password_123 bookstack -e "
UPDATE users SET email='miguel.new@gmail.com', updated_at=NOW() WHERE email='nguetsamiguel@gmail.com';
"
```

### Changer le nom d'un utilisateur

```bash
docker exec bookstack-db mysql -u bookstack_user -pbookstack_password_123 bookstack -e "
UPDATE users SET name='Nouveau Nom', updated_at=NOW() WHERE email='nguetsamiguel@gmail.com';
"
```

### Réinitialiser le mot de passe (via artisan - recommandé)

BookStack ne fournit pas de commande directe, mais vous pouvez :

1. **Via l'interface web** : Settings → Users → Edit → Change password
2. **Via SQL** (déconseillé, nécessite un hash bcrypt valide)

### Désactiver/Activer un utilisateur

BookStack n'a pas de champ "active" par défaut, mais vous pouvez supprimer puis recréer.

---

##  DELETE - Supprimer un utilisateur

### Supprimer un utilisateur via artisan

```bash
docker exec bookstack-app php /app/www/artisan bookstack:delete-users \
  --email="utilisateur@example.com"
```

**Exemple :**
```bash
docker exec bookstack-app php /app/www/artisan bookstack:delete-users \
  --email="nguetsamiguel@gmail.com"
```

### Supprimer un utilisateur via SQL (méthode directe)

```bash
docker exec bookstack-db mysql -u bookstack_user -pbookstack_password_123 bookstack -e "
DELETE FROM users WHERE email='nguetsamiguel@gmail.com';
"
```

**Attention :** La suppression via SQL peut laisser des données orphelines (permissions, activités, etc.). Préférez la commande artisan.

### Supprimer tous les utilisateurs sauf admin

```bash
docker exec bookstack-db mysql -u bookstack_user -pbookstack_password_123 bookstack -e "
DELETE FROM users WHERE email != 'admin@admin.com';
"
```

---

## Gestion des Rôles et Permissions

### Lister les rôles disponibles

```bash
docker exec bookstack-db mysql -u bookstack_user -pbookstack_password_123 bookstack -e "SELECT * FROM roles;"
```

### Voir les rôles d'un utilisateur

```bash
docker exec bookstack-db mysql -u bookstack_user -pbookstack_password_123 bookstack -e "
SELECT u.name, u.email, r.display_name as role 
FROM users u 
JOIN role_user ru ON u.id = ru.user_id 
JOIN roles r ON ru.role_id = r.id 
WHERE u.email='nguetsamiguel@gmail.com';
"
```

### Attribuer un rôle admin à un utilisateur

```bash
docker exec bookstack-db mysql -u bookstack_user -pbookstack_password_123 bookstack -e "
INSERT INTO role_user (user_id, role_id) 
SELECT u.id, r.id FROM users u, roles r 
WHERE u.email='nguetsamiguel@gmail.com' AND r.system_name='admin';
"
```

---

## Opérations de Maintenance

### Réinitialiser le MFA (authentification à deux facteurs)

```bash
docker exec bookstack-app php /app/www/artisan bookstack:reset-mfa \
  --email="nguetsamiguel@gmail.com"
```

### Régénérer les permissions

```bash
docker exec bookstack-app php /app/www/artisan bookstack:regenerate-permissions
```

### Nettoyer les sessions expirées

```bash
docker exec bookstack-app php /app/www/artisan session:gc
```

---

## Statistiques et Rapports

### Nombre d'utilisateurs par rôle

```bash
docker exec bookstack-db mysql -u bookstack_user -pbookstack_password_123 bookstack -e "
SELECT r.display_name as role, COUNT(ru.user_id) as user_count 
FROM roles r 
LEFT JOIN role_user ru ON r.id = ru.role_id 
GROUP BY r.id;
"
```

### Derniers utilisateurs créés

```bash
docker exec bookstack-db mysql -u bookstack_user -pbookstack_password_123 bookstack -e "
SELECT name, email, created_at FROM users ORDER BY created_at DESC LIMIT 10;
"
```

### Utilisateurs actifs (avec activité récente)

```bash
docker exec bookstack-db mysql -u bookstack_user -pbookstack_password_123 bookstack -e "
SELECT DISTINCT u.name, u.email, MAX(a.created_at) as last_activity 
FROM users u 
JOIN activities a ON u.id = a.user_id 
GROUP BY u.id 
ORDER BY last_activity DESC 
LIMIT 10;
"
```

---

## Commandes Utiles

### Accéder au shell MySQL interactif

```bash
docker exec -it bookstack-db mysql -u bookstack_user -pbookstack_password_123 bookstack
```

Une fois dans le shell MySQL :
```sql
SHOW TABLES;
DESCRIBE users;
SELECT * FROM users;
EXIT;
```

### Sauvegarder la base de données

```bash
docker exec bookstack-db mysqldump -u bookstack_user -pbookstack_password_123 bookstack > backup_$(date +%Y%m%d_%H%M%S).sql
```

### Restaurer une sauvegarde

```bash
docker exec -i bookstack-db mysql -u bookstack_user -pbookstack_password_123 bookstack < backup_20260510_103000.sql
```

---

## Notes Importantes

1. **Sécurité** : Ne jamais exposer les credentials de la base de données dans des scripts publics
2. **Backup** : Toujours faire une sauvegarde avant des opérations de suppression massive
3. **Artisan vs SQL** : Préférer les commandes artisan qui gèrent les contraintes d'intégrité
4. **Mot de passe** : Les mots de passe sont hashés avec bcrypt, impossible de les lire en clair

---

## Utilisateurs par Défaut

| Email | Mot de passe | Rôle | Permissions |
|-------|--------------|------|-------------|
| admin@admin.com | password | Admin | Tous les droits |
| guest@example.com | N/A | Public (compte système) | Lecture seule - Ne peut pas se connecter |
| nguetsamiguel@gmail.com | azerty12 | Admin | Tous les droits |
| lecteur@example.com | qwerty | Public (lecture seule) | Voir ci-dessous |

### Note importante sur le compte Guest

Le compte `guest@example.com` est un **compte système réservé** par BookStack pour les visiteurs non authentifiés. Il ne peut **pas se connecter** via le formulaire de login classique. Pour créer un utilisateur avec les mêmes permissions de lecture seule, utilisez le compte `lecteur@example.com` ou créez un nouvel utilisateur avec le rôle "Public".

### Permissions du rôle "Public" (Lecteur)

**Ce que les utilisateurs avec le rôle Public PEUVENT faire :**

- Voir tous les livres (book-view-all)
- Voir ses propres livres (book-view-own)
- Voir toutes les pages (page-view-all)
- Voir ses propres pages (page-view-own)
- Voir tous les chapitres (chapter-view-all)
- Voir ses propres chapitres (chapter-view-own)
- Voir toutes les étagères (bookshelf-view-all)
- Voir ses propres étagères (bookshelf-view-own)
- Exporter du contenu (content-export)

**Ce que les utilisateurs avec le rôle Public NE PEUVENT PAS faire :**

- Créer des livres, pages, chapitres, étagères
- Modifier du contenu existant
- Supprimer quoi que ce soit
- Gérer les utilisateurs (créer, modifier, supprimer)
- Modifier les paramètres de l'application
- Gérer les rôles et permissions
- Uploader des images ou fichiers
- Commenter sur les pages
- Créer des tags
- Accéder aux webhooks ou API

**En résumé :** Les utilisateurs avec le rôle Public sont des lecteurs purs - ils peuvent naviguer et lire tout le contenu, mais ne peuvent rien modifier, créer ou supprimer.

## Guide d'utilisation par rôle

### Utilisateur Lecteur (Rôle Public)

Le rôle Public permet uniquement la consultation du contenu. Voici les actions disponibles :

#### Consulter le contenu

1. **Accéder à l'application**
   - Ouvrir `https://localhost` dans le navigateur
   - Se connecter avec `lecteur@example.com` / `qwerty`

2. **Naviguer dans les livres**
   - Page d'accueil : Liste de tous les livres disponibles
   - Cliquer sur un livre pour voir son contenu
   - Utiliser la barre de recherche en haut pour trouver du contenu

3. **Lire les pages**
   - Cliquer sur une page dans le sommaire d'un livre
   - Utiliser les flèches de navigation pour passer d'une page à l'autre
   - Voir l'historique des révisions (lecture seule)

4. **Consulter les chapitres**
   - Les chapitres organisent les pages dans un livre
   - Cliquer sur un chapitre pour voir toutes ses pages

5. **Explorer les étagères**
   - Menu "Shelves" : Collections thématiques de livres
   - Cliquer sur une étagère pour voir les livres qu'elle contient

6. **Rechercher du contenu**
   - Barre de recherche en haut : Recherche globale
   - Filtres disponibles : Livres, Pages, Chapitres
   - Recherche avancée : Utiliser les opérateurs (AND, OR, NOT)

7. **Exporter du contenu**
   - Sur une page : Bouton "Export" en haut à droite
   - Formats disponibles : PDF, HTML, Markdown, Plain Text
   - Sur un livre : Exporter le livre complet

8. **Mettre en favori** (si activé par l'admin)
   - Icône étoile sur les livres/pages
   - Accès rapide via "My Favourites" dans le menu utilisateur

9. **Voir son profil**
   - Cliquer sur son nom en haut à droite
   - Voir ses informations personnelles (lecture seule)
   - Voir son activité récente

#### Limitations du rôle Lecteur

Les actions suivantes ne sont **pas disponibles** :
- Pas de bouton "Create" (Créer)
- Pas de bouton "Edit" (Modifier)
- Pas de bouton "Delete" (Supprimer)
- Pas d'accès aux paramètres
- Pas de gestion des utilisateurs
- Pas d'upload de fichiers ou images
- Pas de commentaires sur les pages

---

### Utilisateur Administrateur (Rôle Admin)

Le rôle Admin a tous les droits sur l'application. Voici les principales tâches :

#### Gestion du contenu

1. **Créer un livre**
   - Page d'accueil → Bouton "New Book"
   - Remplir : Nom, Description, Image de couverture (optionnel)
   - Définir les permissions (qui peut voir/modifier)
   - Cliquer sur "Save Book"

2. **Créer une page**
   - Dans un livre → Bouton "New Page"
   - Choisir l'éditeur : WYSIWYG ou Markdown
   - Rédiger le contenu
   - Ajouter des tags (optionnel)
   - Cliquer sur "Save Page"

3. **Créer un chapitre**
   - Dans un livre → Bouton "New Chapter"
   - Remplir : Nom, Description
   - Organiser les pages dans le chapitre (glisser-déposer)
   - Cliquer sur "Save Chapter"

4. **Créer une étagère**
   - Menu "Shelves" → Bouton "New Shelf"
   - Remplir : Nom, Description, Image de couverture
   - Ajouter des livres à l'étagère
   - Cliquer sur "Save Shelf"

5. **Modifier du contenu**
   - Sur n'importe quelle page/livre/chapitre : Bouton "Edit"
   - Modifier le contenu
   - Voir l'historique des modifications
   - Restaurer une ancienne version si nécessaire

6. **Supprimer du contenu**
   - Sur n'importe quelle page/livre/chapitre : Bouton "Delete"
   - Confirmation requise
   - Les éléments supprimés peuvent être restaurés (corbeille)

7. **Organiser le contenu**
   - Glisser-déposer pour réorganiser les pages/chapitres
   - Déplacer une page d'un livre à un autre
   - Copier du contenu entre livres

8. **Gérer les permissions**
   - Sur un livre/chapitre/page : Onglet "Permissions"
   - Définir qui peut voir/créer/modifier/supprimer
   - Permissions par rôle ou par utilisateur
   - Hériter des permissions du parent ou définir des permissions spécifiques

#### Gestion des utilisateurs

1. **Créer un utilisateur**
   - Menu "Settings" → "Users" → "Add New User"
   - Remplir : Nom, Email, Mot de passe
   - Attribuer un ou plusieurs rôles
   - Envoyer un email de confirmation (optionnel)

2. **Modifier un utilisateur**
   - Menu "Settings" → "Users" → Cliquer sur un utilisateur
   - Modifier les informations
   - Changer les rôles
   - Réinitialiser le mot de passe
   - Désactiver l'authentification à deux facteurs

3. **Supprimer un utilisateur**
   - Menu "Settings" → "Users" → Cliquer sur un utilisateur
   - Bouton "Delete User"
   - Choisir ce qu'il faut faire du contenu créé par cet utilisateur

4. **Gérer les rôles**
   - Menu "Settings" → "Roles"
   - Créer un nouveau rôle personnalisé
   - Définir les permissions du rôle
   - Attribuer le rôle aux utilisateurs

#### Configuration de l'application

1. **Paramètres généraux**
   - Menu "Settings" → "Settings"
   - Nom de l'application
   - Logo personnalisé
   - Langue par défaut
   - Page d'accueil personnalisée

2. **Paramètres d'authentification**
   - Menu "Settings" → "Settings" → "Registration"
   - Activer/désactiver l'inscription publique
   - Configurer LDAP/SAML/OAuth (optionnel)
   - Activer l'authentification à deux facteurs

3. **Paramètres de sécurité**
   - Forcer HTTPS
   - Définir les en-têtes de sécurité
   - Configurer les webhooks
   - Gérer les tokens API

4. **Personnalisation**
   - Menu "Settings" → "Customization"
   - HTML personnalisé (head/body)
   - CSS personnalisé
   - Thème clair/sombre

5. **Maintenance**
   - Menu "Settings" → "Maintenance"
   - Nettoyer les images non utilisées
   - Nettoyer les révisions anciennes
   - Régénérer les permissions
   - Régénérer l'index de recherche

#### Gestion des médias

1. **Uploader des images**
   - Dans l'éditeur de page : Bouton "Insert Image"
   - Glisser-déposer ou sélectionner un fichier
   - Redimensionner et recadrer
   - Ajouter un texte alternatif (accessibilité)

2. **Gérer les fichiers joints**
   - Sur une page : Onglet "Attachments"
   - Uploader des fichiers (PDF, documents, etc.)
   - Organiser les fichiers
   - Définir les permissions d'accès

3. **Galerie d'images**
   - Menu "Settings" → "Images"
   - Voir toutes les images uploadées
   - Supprimer les images non utilisées
   - Rechercher des images

#### Monitoring et rapports

1. **Voir l'activité**
   - Menu "Settings" → "Audit Log"
   - Voir toutes les actions effectuées
   - Filtrer par utilisateur, type d'action, date
   - Exporter les logs

2. **Statistiques**
   - Tableau de bord : Nombre de livres, pages, utilisateurs
   - Pages les plus consultées
   - Utilisateurs les plus actifs
   - Activité récente

3. **Webhooks**
   - Menu "Settings" → "Webhooks"
   - Créer des webhooks pour notifier des événements
   - Événements : Création, modification, suppression de contenu
   - Tester les webhooks

#### Sauvegarde et restauration

1. **Sauvegarder via l'interface**
   - Menu "Settings" → "Maintenance"
   - Exporter toutes les données (JSON)
   - Télécharger la sauvegarde

2. **Sauvegarder via CLI** (recommandé)
   ```bash
   # Sauvegarde complète
   make backup
   
   # Sauvegarde manuelle de la base de données
   docker exec bookstack-db mysqldump -u bookstack_user -pbookstack_password_123 bookstack > backup.sql
   ```

3. **Restaurer une sauvegarde**
   ```bash
   # Restaurer depuis S3
   make restore FILE=backup_20260510_103000.tar.gz
   
   # Restaurer la base de données
   docker exec -i bookstack-db mysql -u bookstack_user -pbookstack_password_123 bookstack < backup.sql
   ```

#### Commandes CLI utiles pour l'admin

```bash
# Créer un admin
docker exec bookstack-app php /app/www/artisan bookstack:create-admin \
  --email="admin@example.com" --name="Admin" --password="password"

# Régénérer les permissions
docker exec bookstack-app php /app/www/artisan bookstack:regenerate-permissions

# Nettoyer les images non utilisées
docker exec bookstack-app php /app/www/artisan bookstack:cleanup-images

# Régénérer l'index de recherche
docker exec bookstack-app php /app/www/artisan bookstack:regenerate-search

# Vider le cache
docker exec bookstack-app php /app/www/artisan cache:clear

# Voir les logs
docker-compose logs -f app
```

---

### Créer un utilisateur en lecture seule

Pour créer un nouvel utilisateur avec permissions de lecture seule :

```bash
# 1. Générer le hash du mot de passe
docker exec bookstack-app php -r "echo password_hash('votre_mot_de_passe', PASSWORD_BCRYPT);"

# 2. Créer l'utilisateur
docker exec bookstack-db mysql -u bookstack_user -pbookstack_password_123 bookstack -e "
INSERT INTO users (name, email, password, email_confirmed, external_auth_id, slug, created_at, updated_at) 
VALUES ('Nom Utilisateur', 'email@example.com', 'HASH_GENERE', 1, '', 'slug-utilisateur', NOW(), NOW());
"

# 3. Attribuer le rôle Public
docker exec bookstack-db mysql -u bookstack_user -pbookstack_password_123 bookstack -e "
INSERT INTO role_user (user_id, role_id) 
SELECT u.id, r.id FROM users u, roles r 
WHERE u.email='email@example.com' AND r.system_name='public';
"

# 4. Vider le cache
docker exec bookstack-app php /app/www/artisan cache:clear
```

**Exemple complet :**

```bash
# Créer l'utilisateur "lecteur@example.com" avec mot de passe "qwerty"
docker exec bookstack-db mysql -u bookstack_user -pbookstack_password_123 bookstack -e "
INSERT INTO users (name, email, password, email_confirmed, external_auth_id, slug, created_at, updated_at) 
VALUES ('Lecteur Test', 'lecteur@example.com', '\$2y\$12\$JMi.IuShLpsOoA2P65fNletXnrsmu9CJdRsaaTDeGt4nSDk.wPvs.', 1, '', 'lecteur-test', NOW(), NOW());
"

docker exec bookstack-db mysql -u bookstack_user -pbookstack_password_123 bookstack -e "
INSERT INTO role_user (user_id, role_id) 
SELECT u.id, r.id FROM users u, roles r 
WHERE u.email='lecteur@example.com' AND r.system_name='public';
"

docker exec bookstack-app php /app/www/artisan cache:clear
```

---

## Dépannage

### Erreur "Access denied"

Vérifiez les credentials dans `.env` :
```bash
DB_USERNAME=bookstack_user
DB_PASSWORD=bookstack_password_123
```

### Utilisateur créé mais ne peut pas se connecter

Videz le cache :
```bash
docker exec bookstack-app php /app/www/artisan cache:clear
docker exec bookstack-app php /app/www/artisan config:clear
```

### Réinitialiser complètement les utilisateurs

```bash
docker exec bookstack-db mysql -u bookstack_user -pbookstack_password_123 bookstack -e "TRUNCATE users;"
docker exec bookstack-app php /app/www/artisan bookstack:create-admin --email="admin@admin.com" --name="Admin" --password="password"
```
