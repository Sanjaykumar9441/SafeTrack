# ==============================================================
# SafeTrack Admin Dashboard - Multi-stage Docker Build
# Stage 1: Build React app
# Stage 2: Serve with Nginx
# ==============================================================

# ---------- Stage 1: Build ----------
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files for dependency caching
COPY package.json package-lock.json* ./
RUN npm install

# Copy source code and build
COPY . .
RUN npm run build

# ---------- Stage 2: Serve ----------
FROM nginx:alpine

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy build output
COPY --from=builder /app/build /usr/share/nginx/html

# Expose port
EXPOSE 3000

CMD ["nginx", "-g", "daemon off;"]