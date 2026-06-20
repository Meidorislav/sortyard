.PHONY: up down build logs ps db clean restart help

up:
	docker compose up -d --build

down:
	docker compose down

build:
	docker compose build

logs:
	docker compose logs -f

logs-backend:
	docker compose logs -f backend

logs-frontend:
	docker compose logs -f frontend

ps:
	docker compose ps

db:
	docker compose up -d db

clean:
	docker compose down -v

restart:
	docker compose restart

restart-backend:
	docker compose restart backend

restart-frontend:
	docker compose restart frontend

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "  up                build and start all services"
	@echo "  down              stop and remove containers"
	@echo "  build             rebuild images without starting"
	@echo "  logs              tail logs from all services"
	@echo "  logs-backend      tail backend logs only"
	@echo "  logs-frontend     tail frontend logs only"
	@echo "  ps                show running containers"
	@echo "  db                start only the database"
	@echo "  clean             remove containers and volumes (wipes DB!)"
	@echo "  restart           restart all services"
	@echo "  restart-backend   restart backend only"
	@echo "  restart-frontend  restart frontend only"
