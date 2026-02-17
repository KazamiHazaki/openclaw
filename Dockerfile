FROM node:22-bookworm

# ------------------------------------------------------------
# Install Bun (for build scripts)
# ------------------------------------------------------------
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

# ------------------------------------------------------------
# Optional APT packages
# ------------------------------------------------------------
ARG OPENCLAW_DOCKER_APT_PACKAGES=""
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/*; \
    fi

# ------------------------------------------------------------
# Install dependencies
# ------------------------------------------------------------
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

# ------------------------------------------------------------
# Optional Playwright browser install
# ------------------------------------------------------------
ARG OPENCLAW_INSTALL_BROWSER=""
RUN if [ -n "$OPENCLAW_INSTALL_BROWSER" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends xvfb && \
      node /app/node_modules/playwright-core/cli.js install --with-deps chromium && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/*; \
    fi

# ------------------------------------------------------------
# Copy source and build
# ------------------------------------------------------------
COPY . .
RUN pnpm build

# Force pnpm for UI build (Bun can fail on ARM)
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

ENV NODE_ENV=production

# ------------------------------------------------------------
# Runtime permission fix (CRITICAL FOR DOCKER VOLUMES)
# ------------------------------------------------------------
RUN mkdir -p /home/node/.openclaw
RUN chown -R node:node /home/node

# ------------------------------------------------------------
# Drop root privileges
# ------------------------------------------------------------
USER node

# ------------------------------------------------------------
# Smart entrypoint to fix volume permission at runtime
# ------------------------------------------------------------
CMD sh -c "\
  mkdir -p /home/node/.openclaw && \
  chmod -R u+rwX /home/node/.openclaw && \
  exec node dist/index.js gateway --bind loopback --port 18789 --allow-unconfigured \
"
