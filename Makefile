.PHONY: help init plan apply destroy build-lambda clean install test

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

install: ## Install Lambda dependencies
	cd lambda && npm install

build-lambda: install ## Build Lambda function
	cd lambda && npm run build

init: build-lambda ## Initialize Terraform
	terraform init

plan: build-lambda ## Show Terraform plan
	terraform plan

apply: build-lambda ## Apply Terraform configuration
	terraform apply

destroy: ## Destroy all resources
	terraform destroy

clean: ## Clean build artifacts
	rm -rf lambda/node_modules
	rm -rf lambda/dist
	rm -f lambda.zip
	rm -rf .terraform
	rm -f terraform.tfstate*

fmt: ## Format Terraform files
	terraform fmt -recursive

validate: ## Validate Terraform configuration
	terraform validate

outputs: ## Show Terraform outputs
	terraform output

logs-lambda: ## Tail Lambda logs
	aws logs tail /aws/lambda/$$(terraform output -raw lambda_function_name) --follow

logs-ecs: ## Tail ECS logs
	aws logs tail /ecs/$$(terraform output -raw ecs_cluster_name) --follow

invoke-lambda: ## Invoke Lambda function with test payload
	aws lambda invoke \
		--function-name $$(terraform output -raw lambda_function_name) \
		--payload '{"test": "data"}' \
		response.json && cat response.json && rm response.json

test-service1: ## Test Service 1 endpoint
	curl -X POST $$(terraform output -raw service1_endpoint)/process \
		-H "Content-Type: application/json" \
		-d '{"test": "data"}'

test-service2: ## Test Service 2 endpoint
	curl -X POST $$(terraform output -raw service2_endpoint)/process \
		-H "Content-Type: application/json" \
		-d '{"test": "data"}'

test-service3: ## Test Service 3 endpoint
	curl -X POST $$(terraform output -raw service3_endpoint)/process \
		-H "Content-Type: application/json" \
		-d '{"test": "data"}'

all: install build-lambda init apply ## Install, build, and deploy everything