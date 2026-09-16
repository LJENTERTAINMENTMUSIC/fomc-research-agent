# FOMC Research Agent — Multi-platform Docker image
# Replaces Vertex AI Agent Engine deployment with a standard container.
# Supports: Cloud Run, Railway, Render, VPS, DigitalOcean, Hetzner

# ---- Stage 1: Build ----
FROM python:3.11-slim AS builder

WORKDIR /app

# Install build tools
RUN pip install --no-cache-dir uv

# Copy the full project for uv to resolve
COPY pyproject.toml uv.lock* ./
COPY fomc_research/ fomc_research/

# Install production dependencies + serve extras (fastapi, uvicorn)
# FOMC Research Agent - Multi-platform Docker image
FROM python:3.11-slim AS builder

WORKDIR /app

RUN pip install --no-cache-dir uv

# Hatchling requires README.md during package build
COPY pyproject.toml uv.lock* README.md ./
COPY fomc_research/ fomc_research/
COPY deployment/ deployment/

RUN uv sync --no-dev --frozen --extra serve

# FOMC Research Agent - Multi-platform Docker image
FROM python:3.11-slim AS builder
WORKDIR /app
RUN pip install --no-cache-dir uv
COPY pyproject.toml uv.lock* README.md ./
COPY fomc_research/ fomc_research/
COPY deployment/ deployment/
RUN uv sync --no-dev --frozen --extra serve

FROM python:3.11-slim
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/.venv /app/.venv
COPY . .
ENV PATH="/app/.venv/bin:$PATH"
ENV PYTHONUNBUFFERED=1
ENV PORT=8080
EXPOSE 8080
CMD ["python", "deployment/serve_cloudrun.py"]
ENV PORT=8080

EXPOSE 8080

CMD ["python", "deployment/serve_cloudrun.py"]
ENV PATH="/app/.venv/bin:$PATH"
ENV PYTHONUNBUFFERED=1
ENV PORT=8080

# Create non-root user for security
RUN useradd --create-home --shell /bin/bash appuser
USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/api/health || exit 1

# Default: run the HTTP API server
CMD ["python", "deployment/serve_cloudrun.py"]

