.PHONY:  all clean ci test lint format check help

check: ## Format and lint
	@echo "Formatting with stylua..."
	@stylua .
	@echo "Running selene..."
	@selene .

test: ## Run all tests
	@echo "Running tests..."
	@busted

lint: ## Run lint check
	@echo "Running selene..."
	@selene .

format: ## Format code
	@echo "Formatting with stylua..."
	@stylua .

all: check test ## Run linting, formatting check, and tests

ci: check test ## Run all checks (for CI)

help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
