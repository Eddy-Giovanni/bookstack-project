#!/bin/bash
# ============================================
# Script de sauvegarde BookStack
# Destination: AWS S3
# ============================================

set -e

# Variables
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="bookstack_backup_${DATE}"
TEMP_DIR="/tmp/${BACKUP_NAME}"
S3_BUCKET="bookstack-backups"
DB_CONTAINER="bookstack-db"
DB_NAME="bookstack"
DB_USER="postgres"

echo "========================================="
echo "BookStack Backup Script - ${DATE}"
echo "========================================="

# 1. Créer le répertoire temporaire
mkdir -p ${TEMP_DIR}

# 2. Backup de la base de données PostgreSQL
echo " Backup de la base de données..."
docker exec ${DB_CONTAINER} pg_dump -U ${DB_USER} -d ${DB_NAME} -F c > ${TEMP_DIR}/database.dump
echo " Base de données sauvegardée: database.dump"

# 3. Sauvegarde des fichiers uploads
echo " Sauvegarde des fichiers uploads..."
docker run --rm -v bookstack_uploads:/source -v ${TEMP_DIR}:/backup alpine tar czf /backup/uploads.tar.gz -C /source .
echo " Uploads sauvegardés: uploads.tar.gz"

# 4. Sauvegarde des fichiers storage
echo " Sauvegarde des fichiers storage..."
docker run --rm -v bookstack_storage:/source -v ${TEMP_DIR}:/backup alpine tar czf /backup/storage.tar.gz -C /source .
echo " Storage sauvegardé: storage.tar.gz"

# 5. Création d'un fichier d'information
cat > ${TEMP_DIR}/info.txt << EOF
Date de sauvegarde: ${DATE}
Version BookStack: $(docker exec bookstack-app cat /VERSION 2>/dev/null || echo "unknown")
Contenu:
- database.dump: Base de données PostgreSQL
- uploads.tar.gz: Fichiers uploads
- storage.tar.gz: Fichiers storage
EOF

# 6. Compression de tout
echo " Compression de la sauvegarde..."
cd /tmp
tar czf ${BACKUP_NAME}.tar.gz ${BACKUP_NAME}
echo " Archive créée: ${BACKUP_NAME}.tar.gz"

# 7. Upload vers AWS S3
echo " Upload vers AWS S3..."
aws s3 cp ${BACKUP_NAME}.tar.gz s3://${S3_BUCKET}/backups/
echo " Upload terminé"

# 8. Nettoyage
echo " Nettoyage..."
rm -rf ${TEMP_DIR}
rm ${BACKUP_NAME}.tar.gz
echo " Nettoyage terminé"

# 9. Rotation (supprimer les backups de plus de 30 jours)
echo " Rotation des backups..."
aws s3 ls s3://${S3_BUCKET}/backups/ | while read line; do
    file_date=$(echo $line | awk '{print $1}')
    if [[ $file_date < $(date -d "30 days ago" +%Y-%m-%d) ]]; then
        file_name=$(echo $line | awk '{print $4}')
        aws s3 rm s3://${S3_BUCKET}/backups/${file_name}
        echo "🗑️ Supprimé: ${file_name}"
    fi
done

echo "========================================="
echo " Backup terminé avec succès"
echo "========================================="