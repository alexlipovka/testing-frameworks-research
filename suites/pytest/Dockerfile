FROM python:3.12.12-slim
WORKDIR /suite
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY pytest.ini conftest.py aidbox.py ./
COPY tests ./tests
ENTRYPOINT ["pytest"]
