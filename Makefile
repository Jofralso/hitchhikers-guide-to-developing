.PHONY: help install install-dev install-docs lint format test clean docs docs-serve

help:
	@echo "Available targets:"
	@echo "  install      - Install package"
	@echo "  install-dev  - Install package with development dependencies"
	@echo "  install-docs - Install documentation dependencies"
	@echo "  lint         - Run linting checks with ruff"
	@echo "  format       - Format code with ruff"
	@echo "  test         - Run tests with pytest"
	@echo "  tox          - Run tox for all environments"
	@echo "  docs         - Build documentation"
	@echo "  docs-serve   - Serve documentation locally"
	@echo "  clean        - Clean build artifacts"

install:
	pip install -e .

install-dev:
	pip install -e ".[dev]"

install-docs:
	pip install -e ".[docs]"

lint:
	ruff check .
	ruff format --check .

format:
	ruff check --fix .
	ruff format .

test:
	pytest

tox:
	tox

docs:
	mkdocs build

docs-serve:
	mkdocs serve

clean:
	rm -rf build/
	rm -rf dist/
	rm -rf *.egg-info
	rm -rf .pytest_cache
	rm -rf .coverage
	rm -rf htmlcov/
	rm -rf .tox/
	rm -rf site/
	rm -rf .mkdocs_cache/
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
