FROM node:22-slim AS base

ENV TZ=UTC
RUN apt-get update -qq && apt-get install -y -qq ca-certificates curl tzdata git \
 && rm -rf /var/lib/apt/lists/*

FROM base AS source

WORKDIR /app
ARG OKSSKOLTEN_REPO=https://github.com/babarot/oksskolten.git
ARG OKSSKOLTEN_REF=main
RUN git clone --depth 1 --branch ${OKSSKOLTEN_REF} ${OKSSKOLTEN_REPO} .

FROM base AS deps

WORKDIR /app
COPY --from=source /app/package.json /app/package-lock.json* ./
RUN npm ci

FROM deps AS build

COPY --from=source /app/server ./server
COPY --from=source /app/shared ./shared
COPY --from=source /app/src ./src
COPY --from=source /app/migrations ./migrations
COPY --from=source /app/public ./public
COPY --from=source /app/tsconfig.json /app/vite.config.ts /app/tailwind.config.ts /app/postcss.config.js /app/index.html /app/components.json ./
RUN npm run build

FROM base AS runtime

ARG GIT_COMMIT=unknown
ARG GIT_TAG=unknown
ARG BUILD_DATE=unknown
ENV GIT_COMMIT=${GIT_COMMIT}
ENV GIT_TAG=${GIT_TAG}
ENV BUILD_DATE=${BUILD_DATE}

WORKDIR /app
COPY --from=source /app/package.json /app/package-lock.json* ./
RUN npm ci --omit=dev
COPY --from=build /app/dist ./dist
COPY --from=source /app/server ./server
COPY --from=source /app/shared ./shared
COPY --from=source /app/migrations ./migrations

WORKDIR /tmp
RUN curl -fsSL https://claude.ai/install.sh | bash \
 && mv /root/.local/bin/claude /usr/local/bin/claude \
 && chmod 755 /usr/local/bin/claude
WORKDIR /app

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh

RUN addgroup --system app && adduser --system --home /home/app --ingroup app app \
 && mkdir -p /app/data && chown app:app /app/data \
 && mkdir -p /home/app/.claude && chown -R app:app /home/app
USER app

ENV HOME=/home/app
ENV DISABLE_AUTOUPDATER=1

EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:3000/api/health || exit 1
ENTRYPOINT ["entrypoint.sh"]
CMD ["npx", "tsx", "--dns-result-order=ipv4first", "server/index.ts"]
