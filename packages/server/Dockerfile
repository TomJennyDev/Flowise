# Build stage
FROM node:20-alpine AS builder

# Install build dependencies
RUN apk update && \
    apk add --no-cache \
        libc6-compat \
        python3 \
        make \
        g++ \
        build-base \
        cairo-dev \
        pango-dev \
        chromium \
        curl

# Install pnpm
RUN npm install -g pnpm

# Set Node memory limit
ENV NODE_OPTIONS="--max-old-space-size=4096"

WORKDIR /app

# Copy workspace configuration
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./

# Copy all packages (preserve monorepo structure)
COPY packages ./packages

# Install ALL dependencies at workspace root (this is the key!)
RUN pnpm install --no-frozen-lockfile

# Build all packages in correct order (pnpm handles dependencies)
RUN pnpm --filter flowise-components build
RUN pnpm --filter flowise build

# Production stage
FROM node:20-alpine

# Install runtime dependencies
RUN apk update && \
    apk add --no-cache \
        libc6-compat \
        python3 \
        make \
        g++ \
        build-base \
        cairo-dev \
        pango-dev \
        chromium \
        curl


# Set Chromium path
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# Install pnpm
RUN npm install -g pnpm

WORKDIR /app

# Copy built artifacts and node_modules from builder
COPY --from=builder /app/package.json /app/pnpm-lock.yaml /app/pnpm-workspace.yaml /app/.npmrc ./
COPY --from=builder /app/packages ./packages
COPY --from=builder /app/node_modules ./node_modules

# Set working directory to server (but keep workspace context)
WORKDIR /app/packages/server

# Expose port
EXPOSE 3000

# Start server using oclif CLI
CMD ["node", "./bin/run", "start"]
