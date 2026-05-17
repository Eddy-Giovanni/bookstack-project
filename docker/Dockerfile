# Image BookStack personnalisée pour hébergement AWS (ECR / ECS / EC2)
FROM lscr.io/linuxserver/bookstack:latest

LABEL maintainer="fomekongnguetsa@gmail.com"
LABEL version="1.1"
LABEL description="BookStack personnalisé — langue FR, seed utilisateurs README, healthcheck"

# Langue par défaut ; APP_URL et secrets viennent du runtime (.env / task definition)
ENV APP_LANG=fr
ENV BOOKSTACK_SEED_USERS=true

# Contexte de build : répertoire docker/ (docker build -t bookstack .)
# Depuis la racine du projet : docker build -t bookstack docker
COPY cont-init.d/ /custom-cont-init.d/
COPY scripts/seed-bookstack-users.php /etc/bookstack/seed-bookstack-users.php
RUN chmod +x /custom-cont-init.d/* \
    && chmod 644 /etc/bookstack/seed-bookstack-users.php

# BookStack écoute sur le port 80 dans l'image LinuxServer (pas 8080)
EXPOSE 80

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost/login || exit 1
