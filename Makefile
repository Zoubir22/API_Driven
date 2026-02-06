# =============================================================================
# API-DRIVEN INFRASTRUCTURE - Makefile
# =============================================================================
# Orchestration de services AWS via API Gateway et Lambda (LocalStack)
# NO LOCALHOST DEPENDENCY - Uses AWS_ENDPOINT_URL environment variable
# =============================================================================

.PHONY: all install start deploy stop status clean start-ec2 stop-ec2 status-ec2 help check-endpoint

# Configuration - MUST BE SET BY USER
# Example: export AWS_ENDPOINT_URL=https://your-codespace-4566.app.github.dev
ENDPOINT_URL ?= $(AWS_ENDPOINT_URL)
REGION = us-east-1
LAMBDA_NAME = ec2-controller
API_NAME = ec2-api

# Colors for output
GREEN = \033[0;32m
YELLOW = \033[0;33m
RED = \033[0;31m
NC = \033[0m

# =============================================================================
# Main Commands
# =============================================================================

## all: Complete setup - Install, start LocalStack, and deploy infrastructure
all: install start wait-ready deploy
	@echo ""
	@echo "$(GREEN)🎉 Tout est prêt ! Utilisez 'make help' pour voir les commandes disponibles.$(NC)"

## help: Show this help message
help:
	@echo "$(GREEN)==============================================================================$(NC)"
	@echo "$(GREEN) API-DRIVEN INFRASTRUCTURE - Commandes disponibles$(NC)"
	@echo "$(GREEN)==============================================================================$(NC)"
	@echo ""
	@echo "$(RED)⚠️  IMPORTANT: Définissez AWS_ENDPOINT_URL avant utilisation !$(NC)"
	@echo "   export AWS_ENDPOINT_URL=<votre-url-localstack>"
	@echo ""
	@echo "$(YELLOW)Setup:$(NC)"
	@echo "  make install     - Installer les dépendances (LocalStack, awslocal)"
	@echo "  make start       - Démarrer LocalStack en arrière-plan"
	@echo "  make stop        - Arrêter LocalStack"
	@echo "  make status      - Vérifier le statut des services LocalStack"
	@echo ""
	@echo "$(YELLOW)Déploiement:$(NC)"
	@echo "  make deploy      - Déployer l'infrastructure (EC2, Lambda, API Gateway)"
	@echo "  make all         - Installation complète (install + start + deploy)"
	@echo ""
	@echo "$(YELLOW)Contrôle EC2 via API:$(NC)"
	@echo "  make start-ec2   - Démarrer l'instance EC2 via API"
	@echo "  make stop-ec2    - Arrêter l'instance EC2 via API"
	@echo "  make status-ec2  - Obtenir le statut de l'instance EC2 via API"
	@echo ""
	@echo "$(YELLOW)Nettoyage:$(NC)"
	@echo "  make clean       - Supprimer l'infrastructure et arrêter LocalStack"
	@echo ""

## check-endpoint: Verify AWS_ENDPOINT_URL is set
check-endpoint:
	@if [ -z "$(ENDPOINT_URL)" ]; then \
		echo "$(RED)❌ ERROR: AWS_ENDPOINT_URL is not set!$(NC)"; \
		echo ""; \
		echo "Please set your endpoint URL:"; \
		echo "  export AWS_ENDPOINT_URL=<your-localstack-url>"; \
		echo ""; \
		echo "Examples:"; \
		echo "  - GitHub Codespaces: Voir l'onglet PORTS pour l'URL publique"; \
		exit 1; \
	fi
	@echo "$(GREEN)✅ AWS_ENDPOINT_URL is set: $(ENDPOINT_URL)$(NC)"

# =============================================================================
# Installation & LocalStack Management
# =============================================================================

## install: Install dependencies
install:
	@echo "$(YELLOW)📦 Installation des dépendances...$(NC)"
	@pip3 install --upgrade pip --quiet 2>/dev/null || pip3 install --upgrade pip --quiet --break-system-packages 2>/dev/null || true
	@pip3 install localstack awscli-local boto3 --quiet 2>/dev/null || pip3 install localstack awscli-local boto3 --quiet --break-system-packages 2>/dev/null || pip install localstack awscli-local boto3 --quiet 2>/dev/null || true
	@echo "$(GREEN)✅ Dépendances installées$(NC)"
	@echo "$(YELLOW)📌 Vérification de awslocal...$(NC)"
	@which awslocal && echo "$(GREEN)✅ awslocal disponible$(NC)" || echo "$(RED)⚠️  awslocal non trouvé, réessayez 'make install'$(NC)"

## start: Start LocalStack in background
start:
	@echo "$(YELLOW)🚀 Démarrage de LocalStack...$(NC)"
	@export AWS_ACCESS_KEY_ID=test && \
	 export AWS_SECRET_ACCESS_KEY=test && \
	 export AWS_DEFAULT_REGION=$(REGION) && \
	 localstack start -d 2>/dev/null || echo "LocalStack déjà en cours d'exécution"
	@echo "$(GREEN)✅ LocalStack démarré$(NC)"
	@echo ""
	@echo "$(YELLOW)⚠️  IMPORTANT: Définissez AWS_ENDPOINT_URL avec l'URL de l'onglet PORTS$(NC)"
	@echo "   Le port peut être 4566 ou différent selon votre environnement"

## wait-ready: Wait for LocalStack to be ready
wait-ready:
	@echo "$(YELLOW)⏳ Attente du démarrage de LocalStack (20s)...$(NC)"
	@sleep 20
	@echo "$(GREEN)✅ LocalStack prêt$(NC)"

## stop: Stop LocalStack
stop:
	@echo "$(YELLOW)🛑 Arrêt de LocalStack...$(NC)"
	@localstack stop || true
	@echo "$(GREEN)✅ LocalStack arrêté$(NC)"

## status: Check LocalStack services status
status:
	@echo "$(YELLOW)📊 Statut des services LocalStack:$(NC)"
	@localstack status services 2>/dev/null || echo "$(RED)LocalStack n'est pas démarré$(NC)"

# =============================================================================
# Infrastructure Deployment
# =============================================================================

## deploy: Deploy all infrastructure (EC2, Lambda, API Gateway)
deploy: check-endpoint
	@echo "$(YELLOW)🔧 Déploiement de l'infrastructure...$(NC)"
	@chmod +x scripts/create-infrastructure.sh
	@bash scripts/create-infrastructure.sh

# =============================================================================
# EC2 API Control
# =============================================================================

## start-ec2: Start EC2 instance via API Gateway
start-ec2: check-endpoint
	@echo "$(YELLOW)▶️  Démarrage de l'instance EC2 via API...$(NC)"
	@API_ID=$$(cat /tmp/api_gateway_id.txt 2>/dev/null) && \
	 curl -s -X POST "$(ENDPOINT_URL)/restapis/$$API_ID/prod/_user_request_/ec2" \
	   -H "Content-Type: application/json" \
	   -d '{"action":"start"}' | python3 -m json.tool

## stop-ec2: Stop EC2 instance via API Gateway
stop-ec2: check-endpoint
	@echo "$(YELLOW)⏹️  Arrêt de l'instance EC2 via API...$(NC)"
	@API_ID=$$(cat /tmp/api_gateway_id.txt 2>/dev/null) && \
	 curl -s -X POST "$(ENDPOINT_URL)/restapis/$$API_ID/prod/_user_request_/ec2" \
	   -H "Content-Type: application/json" \
	   -d '{"action":"stop"}' | python3 -m json.tool

## status-ec2: Get EC2 instance status via API Gateway
status-ec2: check-endpoint
	@echo "$(YELLOW)📊 Statut de l'instance EC2 via API...$(NC)"
	@API_ID=$$(cat /tmp/api_gateway_id.txt 2>/dev/null) && \
	 curl -s -X POST "$(ENDPOINT_URL)/restapis/$$API_ID/prod/_user_request_/ec2" \
	   -H "Content-Type: application/json" \
	   -d '{"action":"status"}' | python3 -m json.tool

# =============================================================================
# Cleanup
# =============================================================================

## clean: Remove all infrastructure and stop LocalStack
clean:
	@echo "$(YELLOW)🧹 Nettoyage de l'environnement...$(NC)"
	@localstack stop 2>/dev/null || true
	@rm -f /tmp/ec2_instance_id.txt /tmp/api_gateway_id.txt /tmp/lambda_function.zip
	@echo "$(GREEN)✅ Environnement nettoyé$(NC)"
