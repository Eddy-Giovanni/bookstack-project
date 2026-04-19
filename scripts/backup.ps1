# backup.ps1 - Version PowerShell pour Windows
$DATE = Get-Date -Format "yyyyMMdd_HHmmss"
$BACKUP_NAME = "bookstack_backup_${DATE}"
$TEMP_DIR = "C:\temp\$BACKUP_NAME"
$S3_BUCKET = "bookstack-backups"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "BookStack Backup Script - $DATE" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Créer le dossier temporaire
New-Item -ItemType Directory -Path $TEMP_DIR -Force | Out-Null

# Backup PostgreSQL
Write-Host " Backup de la base de données..." -ForegroundColor Yellow
docker exec bookstack-db pg_dump -U bookstack_user -d bookstack -F c > "$TEMP_DIR\database.dump"
Write-Host " Base de données sauvegardée" -ForegroundColor Green

# Backup des volumes
Write-Host " Backup des volumes..." -ForegroundColor Yellow
docker run --rm -v bookstack_uploads:/source -v ${TEMP_DIR}:/backup alpine tar czf /backup/uploads.tar.gz -C /source .
docker run --rm -v bookstack_storage:/source -v ${TEMP_DIR}:/backup alpine tar czf /backup/storage.tar.gz -C /source .
Write-Host " Volumes sauvegardés" -ForegroundColor Green

# Compression
Write-Host " Compression..." -ForegroundColor Yellow
Compress-Archive -Path "$TEMP_DIR\*" -DestinationPath "C:\temp\$BACKUP_NAME.zip" -Force
Write-Host " Archive créée" -ForegroundColor Green

# Upload vers S3
Write-Host " Upload vers S3..." -ForegroundColor Yellow
aws s3 cp "C:\temp\$BACKUP_NAME.zip" "s3://$S3_BUCKET/backups/"
Write-Host " Upload terminé" -ForegroundColor Green

# Nettoyage
Remove-Item -Path $TEMP_DIR -Recurse -Force
Remove-Item "C:\temp\$BACKUP_NAME.zip" -Force

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Backup terminé" -ForegroundColor Green