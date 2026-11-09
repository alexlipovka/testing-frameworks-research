FROM python:3.12.12-slim
COPY --from=ghcr.io/astral-sh/uv:0.13.7 /uv /usr/local/bin/uv
WORKDIR /suite
COPY pyproject.toml uv.lock ./
RUN uv sync --locked --no-cache
ENV PATH=/suite/.venv/bin:$PATH
COPY pytest.ini conftest.py aidbox.py ./
COPY tests ./tests
ENTRYPOINT ["pytest"]
