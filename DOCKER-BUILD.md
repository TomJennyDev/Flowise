# Flowise Docker Build Guide

Hướng dẫn build và chạy Flowise với Docker.

## Image Size Comparison

| Method                       | Image Size   | Build Time | Use Case                   |
| ---------------------------- | ------------ | ---------- | -------------------------- |
| **Official** (npm package)   | ~500MB       | ~2 min     | Production, quick deploy   |
| **From Source** (your build) | ~800MB-1.5GB | ~5-10 min  | Development, customization |
| **Unoptimized**              | ~2.8GB       | ~10 min    | Includes all source files  |

## Build Docker Images

### Build từ root directory của project:

```bash
# Build UI image
docker build -f packages/ui/Dockerfile -t flowise-ui:latest .

# Build Server image
docker build -f packages/server/Dockerfile -t flowise-server:latest .
```

**Lưu ý:**

-   Phải build từ thư mục gốc (root) của project vì Dockerfile cần access toàn bộ workspace
-   Build context là `.` (thư mục hiện tại - root)
-   Sử dụng flag `-f` để chỉ định đường dẫn đến Dockerfile

## Chạy với Docker Compose

```bash
# Start tất cả services
docker-compose up -d

# Xem logs
docker-compose logs -f

# Stop services
docker-compose down

# Stop và xóa volumes
docker-compose down -v
```

## Chạy riêng từng container

### UI Only:

```bash
docker run -d \
  --name flowise-ui \
  -p 8080:80 \
  flowise-ui:latest
```

Truy cập: http://localhost:8080

### Server Only:

```bash
docker run -d \
  --name flowise-server \
  -p 3000:3000 \
  -v flowise_data:/root/.flowise \
  flowise-server:latest
```

API endpoint: http://localhost:3000

## Kiểm tra images đã build

```bash
docker images | grep flowise
```

Output:

```
flowise-ui       latest    xxx    xxx ago    ~64MB
flowise-server   latest    xxx    xxx ago    ~XXX MB
```

## Cấu trúc Files

```
Flowise/
├── docker-compose.yml          # Docker Compose configuration
├── packages/
│   ├── ui/
│   │   ├── Dockerfile         # UI build configuration
│   │   └── nginx.conf         # Nginx configuration cho UI
│   └── server/
│       └── Dockerfile         # Server build configuration
```

## Environment Variables

### Server (.env hoặc docker-compose.yml):

```env
PORT=3000
DATABASE_PATH=/root/.flowise
APIKEY_PATH=/root/.flowise
SECRETKEY_PATH=/root/.flowise
LOG_PATH=/root/.flowise/logs
NODE_ENV=production
```

### UI:

```env
VITE_API_URL=http://localhost:3000
```

## Troubleshooting

### Build failed do thiếu memory:

-   Tăng Docker memory limit trong Docker Desktop Settings
-   Dockerfiles đã set `NODE_OPTIONS="--max-old-space-size=4096"`

### Port đã bị sử dụng:

```bash
# Đổi port trong docker-compose.yml hoặc khi run:
docker run -p 8081:80 flowise-ui:latest
```

### Xem logs khi container chạy:

```bash
docker logs flowise-ui
docker logs flowise-server
```

## Production Notes

1. **UI**: Sử dụng nginx để serve static files đã được build
2. **Server**: Chạy production build với pnpm start
3. **Data Persistence**: Sử dụng volumes để lưu database và configs
4. **Network**: Services kết nối qua Docker network `flowise-network`

## Cleanup

```bash
# Xóa tất cả Flowise containers và images
docker-compose down -v
docker rmi flowise-ui:latest flowise-server:latest

# Xóa dangling images
docker image prune -f
```
