# =============================================================================
# API-DRIVEN INFRASTRUCTURE - Makefile
# =============================================================================
# Orchestration de services AWS via API Gateway et Lambda (LocalStack)
# =============================================================================

.PHONY: all install start deploy stop status clean start-ec2 stop-ec2 status-ec2 help check-endpoint

# Configuration
ENDPOINT_URL ?= $(AWS_ENDPOINT_URL)
REGION = us-east-1

# Colors
GREEN = \033[0;32m
YELLOW = \033[0;33m
RED = \033[0;31m
NC = \033[0m

# =============================================================================
# Main Commands
# =============================================================================

## help: Show this help message
help:
	@echo "$(GREEN)============================================$(NC)"
	@echo "$(GREEN) API-DRIVEN INFRASTRUCTURE$(NC)"
	@echo "$(GREEN)============================================$(NC)"
	@echo ""
	@echo "$(RED)⚠️  Définissez AWS_ENDPOINT_URL avant utilisation !$(NC)"
	@echo ""
	@echo "$(YELLOW)Setup:$(NC)"
	@echo "  make install     - Installer les dépendances"
	@echo "  make start       - Démarrer LocalStack"
	@echo "  make deploy      - Déployer l'infrastructure"
	@echo ""
	@echo "$(YELLOW)Contrôle EC2:$(NC)"
	@echo "  make status-ec2  - Statut de l'instance"
	@echo "  make stop-ec2    - Arrêter l'instance"
	@echo "  make start-ec2   - Démarrer l'instance"
	@echo ""
	@echo "$(YELLOW)Nettoyage:$(NC)"
	@echo "  make clean       - Nettoyer"
	@echo ""

## check-endpoint: Verify AWS_ENDPOINT_URL is set
check-endpoint:
	@if [ -z "$(ENDPOINT_URL)" ]; then \
		echo "$(RED)❌ AWS_ENDPOINT_URL non défini !$(NC)"; \
		echo "export AWS_ENDPOINT_URL=https://votre-url.app.github.dev"; \
		exit 1; \
	fi
	@echo "$(GREEN)✅ AWS_ENDPOINT_URL: $(ENDPOINT_URL)$(NC)"

# =============================================================================
# Installation & LocalStack
# =============================================================================

## install: Install dependencies
install:
	@echo "$(YELLOW)📦 Installation des dépendances...$(NC)"
	@pip3 install localstack boto3 --quiet 2>/dev/null || pip3 install localstack boto3 --quiet --break-system-packages 2>/dev/null || pip install localstack boto3 --quiet
	@echo "$(GREEN)✅ Dépendances installées$(NC)"

## start: Start LocalStack
start:
	@echo "$(YELLOW)🚀 Démarrage de LocalStack...$(NC)"
	@localstack start -d 2>/dev/null || echo "LocalStack déjà démarré"
	@echo "$(GREEN)✅ LocalStack démarré$(NC)"
	@echo "$(YELLOW)⚠️  Rendez le port 4566 PUBLIC dans l'onglet PORTS$(NC)"

## stop: Stop LocalStack
stop:
	@localstack stop 2>/dev/null || true
	@echo "$(GREEN)✅ LocalStack arrêté$(NC)"

## status: Check LocalStack status
status:
	@localstack status services 2>/dev/null || echo "$(RED)LocalStack non démarré$(NC)"

# =============================================================================
# Deployment
# =============================================================================

## deploy: Deploy infrastructure
deploy: check-endpoint
	@echo "$(YELLOW)🔧 Déploiement de l'infrastructure...$(NC)"
	@python3 scripts/create-infrastructure.py

# =============================================================================
# EC2 API Control
# =============================================================================

## start-ec2: Start EC2 instance
start-ec2: check-endpoint
	@echo "$(YELLOW)▶️  Démarrage de l'instance EC2...$(NC)"
	@API_ID=$$(cat /tmp/api_gateway_id.txt 2>/dev/null) && \
	 curl -s -X POST "$(ENDPOINT_URL)/restapis/$$API_ID/prod/_user_request_/ec2" \
	   -H "Content-Type: application/json" \
	   -d '{"action":"start"}' | python3 -m json.tool

## stop-ec2: Stop EC2 instance
stop-ec2: check-endpoint
	@echo "$(YELLOW)⏹️  Arrêt de l'instance EC2...$(NC)"
	@API_ID=$$(cat /tmp/api_gateway_id.txt 2>/dev/null) && \
	 curl -s -X POST "$(ENDPOINT_URL)/restapis/$$API_ID/prod/_user_request_/ec2" \
	   -H "Content-Type: application/json" \
	   -d '{"action":"stop"}' | python3 -m json.tool

## status-ec2: Get EC2 status
status-ec2: check-endpoint
	@echo "$(YELLOW)📊 Statut de l'instance EC2...$(NC)"
	@API_ID=$$(cat /tmp/api_gateway_id.txt 2>/dev/null) && \
	 curl -s -X POST "$(ENDPOINT_URL)/restapis/$$API_ID/prod/_user_request_/ec2" \
	   -H "Content-Type: application/json" \
	   -d '{"action":"status"}' | python3 -m json.tool

# =============================================================================
# Cleanup
# =============================================================================

## clean: Clean up
clean:
	@localstack stop 2>/dev/null || true
	@rm -f /tmp/ec2_instance_id.txt /tmp/api_gateway_id.txt /tmp/lambda_function.zip
	@echo "$(GREEN)✅ Environnement nettoyé$(NC)"
