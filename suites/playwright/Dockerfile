FROM node:24.11.1-bookworm-slim
WORKDIR /suite
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY . .
# run.sh runs as the host user, who must be able to create test-results/
RUN chmod a+w /suite
ENTRYPOINT ["npx", "playwright", "test"]
