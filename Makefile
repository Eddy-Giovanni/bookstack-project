.PHONY: help up down build logs backup restore clean

help:
	@echo "Commandes disponibles :"
	@echo "  make up       - Démarrer tous les services"
	@echo "  make down     - Arrêter tous les services"
	@echo "  make build    - Reconstruire les images"
	@echo "  make logs     - Afficher les logs"
	@echo "  make backup   - Sauvegarde vers S3"
	@echo "  make restore  - Restauration depuis S3"
	@echo "  make clean    - Nettoyer volumes et conteneurs"

up:
	docker-compose up -d
	@echo " Services démarrés"
	@echo " BookStack: https://localhost"
	@echo " Grafana: http://localhost:3000 (admin/admin)"

down:
	docker-compose down
	@echo " Services arrêtés"

build:
	docker-compose build --no-cache
	@echo " Images reconstruites"

logs:
	docker-compose logs -f

backup:
	powershell -ExecutionPolicy Bypass -File scripts/backup.ps1

restore:
	@echo "Usage: make restore FILE=nom_du_fichier"
	@echo "Exemple: make restore FILE=bookstack_backup_20241201_120000.zip"

ifdef FILE
	powershell -ExecutionPolicy Bypass -File scripts/restore.ps1 -BackupFile $(FILE)
endif

clean:
	docker-compose down -v --rmi all
	@echo " Nettoyage complet"

shell:
	docker-compose exec app sh

psql:
	docker-compose exec database psql -U postgres -d bookstack

test:
	curl -k https://localhost
	@echo " Test HTTPS OK"