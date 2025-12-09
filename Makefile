.PHONY: help build-lambdas deploy-infra build-esp32 flash-esp32 setup-worker clean

help:
	@echo "REM System - Available Commands"
	@echo ""
	@echo "Cloud Infrastructure:"
	@echo "  make build-lambdas    - Build all Lambda functions"
	@echo "  make deploy-infra     - Deploy AWS infrastructure with Terraform"
	@echo "  make destroy-infra    - Destroy AWS infrastructure"
	@echo "  make outputs          - Show Terraform outputs"
	@echo ""
	@echo "ESP32 Firmware:"
	@echo "  make build-esp32      - Build ESP32 firmware"
	@echo "  make flash-esp32      - Flash firmware to ESP32"
	@echo "  make monitor-esp32    - Monitor ESP32 serial output"
	@echo ""
	@echo "GPU Worker:"
	@echo "  make setup-worker     - Setup Python virtual environment"
	@echo "  make run-worker       - Run GPU worker"
	@echo ""
	@echo "Utilities:"
	@echo "  make clean            - Clean build artifacts"
	@echo "  make test             - Run all tests"

# Lambda Functions
build-lambdas:
	@echo "Building Lambda functions..."
	cd cloud/lambdas/ingest-audio && npm install && npm run build
	cd cloud/lambdas/transcription-dispatcher && npm install && npm run build
	cd cloud/lambdas/query-transcripts && npm install && npm run build
	@echo "Lambda functions built successfully"

clean-lambdas:
	@echo "Cleaning Lambda build artifacts..."
	rm -rf cloud/lambdas/*/node_modules
	rm -rf cloud/lambdas/*/dist
	rm -f cloud/lambdas/*/function.zip

# Terraform
deploy-infra: build-lambdas
	@echo "Deploying infrastructure..."
	cd cloud/infra && terraform init && terraform apply
	@echo "Deployment complete!"
	@echo ""
	@echo "Important outputs:"
	@make outputs

plan-infra:
	@echo "Planning infrastructure changes..."
	cd cloud/infra && terraform plan

destroy-infra:
	@echo "WARNING: This will destroy all infrastructure!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd cloud/infra && terraform destroy; \
	fi

outputs:
	@cd cloud/infra && terraform output

outputs-json:
	@cd cloud/infra && terraform output -json

# ESP32
build-esp32:
	@echo "Building ESP32 firmware..."
	cd esp32 && pio run

flash-esp32: build-esp32
	@echo "Flashing ESP32..."
	cd esp32 && pio run --target upload

monitor-esp32:
	@echo "Monitoring ESP32 (Ctrl+C to exit)..."
	cd esp32 && pio device monitor

clean-esp32:
	@echo "Cleaning ESP32 build..."
	cd esp32 && pio run --target clean

# GPU Worker
setup-worker:
	@echo "Setting up GPU worker..."
	cd cloud/gpu-worker && python3 -m venv venv
	cd cloud/gpu-worker && . venv/bin/activate && pip install -r requirements.txt
	@echo "GPU worker setup complete"
	@echo "Don't forget to configure .env file!"

run-worker:
	@echo "Starting GPU worker..."
	cd cloud/gpu-worker && . venv/bin/activate && python src/worker.py

# Testing
test-upload:
	@echo "Testing audio upload endpoint..."
	@if [ -z "$(API_URL)" ] || [ -z "$(API_KEY)" ]; then \
		echo "Error: Set API_URL and API_KEY environment variables"; \
		exit 1; \
	fi
	@echo "Upload test not implemented - use ESP32 or curl"

test-query:
	@echo "Testing query endpoint..."
	@if [ -z "$(API_URL)" ]; then \
		echo "Error: Set API_URL environment variable"; \
		exit 1; \
	fi
	curl -X POST $(API_URL)/query \
		-H "Content-Type: application/json" \
		-d '{"userId":"default-user","query":"test","limit":5}'

# Cleanup
clean: clean-lambdas clean-esp32
	@echo "Cleaning Python cache..."
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	@echo "Cleanup complete"

# Development
dev-setup:
	@echo "Setting up development environment..."
	@echo "1. Installing Lambda dependencies..."
	@make build-lambdas
	@echo "2. Setting up GPU worker..."
	@make setup-worker
	@echo ""
	@echo "Development setup complete!"
	@echo ""
	@echo "Next steps:"
	@echo "1. Configure cloud/infra/terraform.tfvars"
	@echo "2. Configure esp32/include/secrets.h"
	@echo "3. Configure cloud/gpu-worker/.env"
	@echo "4. Run 'make deploy-infra' to deploy cloud infrastructure"

# Quick deploy everything
deploy-all: deploy-infra flash-esp32
	@echo ""
	@echo "==================================="
	@echo "REM System Deployed!"
	@echo "==================================="
	@echo ""
	@echo "Next steps:"
	@echo "1. Configure GPU worker .env with Terraform outputs"
	@echo "2. Run 'make run-worker' to start transcription worker"
	@echo "3. Power on ESP32 and check serial monitor"

