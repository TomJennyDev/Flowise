# Build stage - Build UI from root context
FROM node:20-alpine AS builder

# Install pnpm
RUN npm install -g pnpm

# Set Node memory limit for build
ENV NODE_OPTIONS="--max-old-space-size=4096"

WORKDIR /app

# Copy entire workspace
COPY . .

# Install all dependencies (disable husky git hooks)
RUN pnpm install

# Build UI
WORKDIR /app/packages/ui
RUN pnpm build

# Production stage
FROM nginx:alpine

# Copy built files from builder stage
COPY --from=builder /app/packages/ui/build /usr/share/nginx/html

# Copy custom nginx configuration from build context
COPY packages/ui/nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
