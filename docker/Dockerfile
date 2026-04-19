# Étape 1 : Utiliser l'image officielle BookStack comme base
FROM lscr.io/linuxserver/bookstack:latest

# Étape 2 : Définir les labels (métadonnées)
LABEL maintainer="votre-email@example.com"
LABEL version="1.0"
LABEL description="BookStack personnalisé pour TP11"

# Étape 3 : Variables d'environnement par défaut
ENV APP_URL=https://localhost
ENV APP_LANG=fr

# Étape 4 : Créer un utilisateur non-root pour la sécurité
# (BookStack officiel gère déjà cela, mais on vérifie)
RUN if ! id -u abc >/dev/null 2>&1; then \
        addgroup -g 1000 abc && \
        adduser -D -u 1000 -G abc abc; \
    fi

# Étape 5 : Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/login || exit 1

# Étape 6 : Exposition du port
EXPOSE 8080

# Étape 7 : Commande de démarrage (déjà définie dans l'image officielle)
# On garde celle par défaut