.PHONY:  all clean ci test lint format check help

help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

test: ## Run all tests with busted
	@echo "Running tests with busted..."
	@busted
	# @nvim --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"

test-watch: ## Run tests in watch mode
	@echo "Running tests in watch mode..."
	@while true; do \
		make test; \
		inotifywait -qre close_write lua/ tests/; \
	done

lint: ## Run luacheck and selene
	@echo "Running luacheck..."
	@luacheck lua/ tests/
	@echo "Running selene..."
	@selene lua/ tests/

format: ## Format code with stylua
	@echo "Formatting code with stylua..."
	@stylua lua/ tests/

check: ## Check formatting without modifying
	@echo "Checking code formatting..."
	@stylua --check lua/ tests/

all: lint check test ## Run linting, formatting check, and tests

ci: lint check test ## Run all checks (for CI)
