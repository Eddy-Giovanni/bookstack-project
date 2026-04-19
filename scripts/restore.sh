#!/bin/bash
# ============================================
# Script de restauration BookStack
# Source: AWS S3
# ============================================

set -e

# Variables
BACKUP_FILE=$1
S3_BUCKET="bookstack-backups"
TEMP_DIR="/tmp/restore_$(date +%s)"

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: ./restore.sh <nom_du_fichier_backup>"
    echo "Exemple: ./restore.sh bookstack_backup_20241201_120000.tar.gz"
    echo ""
    echo "Backups disponibles dans S3:"
    aws s3 ls s3://${S3_BUCKET}/backups/
    exit 1
fi

echo "========================================="
echo "BookStack Restore Script"
echo "Fichier: ${BACKUP_FILE}"
echo "========================================="

# 1. Télécharger depuis S3
echo " Téléchargement depuis S3..."
aws s3 cp s3://${S3_BUCKET}/backups/${BACKUP_FILE} ${BACKUP_FILE}
echo " Téléchargement terminé"

# 2. Créer le répertoire temporaire
mkdir -p ${TEMP_DIR}

# 3. Extraire l'archive
echo " Extraction de l'archive..."
tar xzf ${BACKUP_FILE} -C ${TEMP_DIR}
echo " Extraction terminée"

# 4. Arrêter les services
echo "⏹ Arrêt des services..."
docker-compose down
echo " Services arrêtés"

# 5. Restaurer la base de données
echo " Restauration de la base de données..."
docker-compose up -d database
sleep 10
docker exec -i bookstack-db pg_restore -U bookstack_user -d bookstack -c < ${TEMP_DIR}/bookstack_backup_*/database.dump
echo " Base de données restaurée"

# 6. Restaurer les uploads
echo " Restauration des uploads..."
docker run --rm -v bookstack_uploads:/target -v ${TEMP_DIR}:/backup alpine sh -c "rm -rf /target/* && tar xzf /backup/*/uploads.tar.gz -C /target"
echo " Uploads restaurés"

# 7. Restaurer les fichiers storage
echo " Restauration des fichiers storage..."
docker run --rm -v bookstack_storage:/target -v ${TEMP_DIR}:/backup alpine sh -c "rm -rf /target/* && tar xzf /backup/*/storage.tar.gz -C /target"
echo " Storage restauré"

# 8. Redémarrer tous les services
echo " Redémarrage des services..."
docker-compose up -d
echo " Services redémarrés"

# 9. Nettoyage
echo " Nettoyage..."
rm -rf ${TEMP_DIR}
rm ${BACKUP_FILE}
echo " Nettoyage terminé"

echo "========================================="
echo " Restauration terminée avec succès"
echo "========================================="