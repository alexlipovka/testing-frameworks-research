FROM python:3.12.12-slim
COPY --from=ghcr.io/astral-sh/uv:0.13.7 /uv /usr/local/bin/uv
WORKDIR /suite
COPY pyproject.toml uv.lock ./
RUN uv sync --locked --no-cache --compile-bytecode
ENV PATH=/suite/.venv/bin:$PATH
COPY app ./app
COPY tests ./tests
ENTRYPOINT ["pytest"]
