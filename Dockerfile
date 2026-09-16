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
COPY deployment/ deployment/
COPY fomc_research/ fomc_research/
ENV PATH="/app/.venv/bin:$PATH"
ENV PYTHONUNBUFFERED=1
ENV PORT=8080
EXPOSE 8080
CMD ["python", "deployment/serve_cloudrun.py"]
