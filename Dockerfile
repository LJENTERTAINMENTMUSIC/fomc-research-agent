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
# Skip agent-engine extras (not needed for alternative deployment)
RUN uv sync --no-dev --frozen --extra serve 2>/dev/null || \
    uv sync --no-dev --extra serve

# ---- Stage 2: Runtime ----
FROM python:3.11-slim

WORKDIR /app

# Install curl for healthchecks
RUN apt-get update && apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# Copy virtual environment from builder
COPY --from=builder /app/.venv /app/.venv

# Copy application code
COPY . .

# Add venv to PATH
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

