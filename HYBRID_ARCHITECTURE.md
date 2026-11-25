# 🦀 Piposmart Pro - Hybrid Architecture (Go + Rust)

## Overview

Piposmart Pro menggunakan hybrid architecture dengan:
- **Go (Gin)**: Main API Server & orchestration
- **Rust (Axum)**: High-performance microservices

## Architecture

```
┌─────────────────────────────┐
│   Flutter Mobile App        │
└──────────────┬──────────────┘
               │
        ┌──────▼──────┐
        │  API Gateway│
        │  (Go - Port │
        │  8080)      │
        └──────┬──────┘
               │
      ┌────────┼────────┐
      │        │        │
      ▼        ▼        ▼
   Image   Report  Analytics
  Service  Service  Service
  (Rust)   (Rust)   (Rust)
  :3001    :3002    :3003
```

## Services

### 1. Main API (Go)
**Port**: 8080
**Technology**: Go + Gin Framework

Responsibilities:
- Authentication & Authorization
- Order management
- User management
- Payment processing
- Inventory management
- Route requests to Rust services

### 2. Image Service (Rust)
**Port**: 3001
**Technology**: Rust + Axum

Responsibilities:
- Image compression & optimization
- Thumbnail generation
- Image format conversion
- Image validation

### 3. Report Service (Rust)
**Port**: 3002
**Technology**: Rust + Axum

Responsibilities:
- PDF generation
- Excel report creation
- Data aggregation
- Report caching

### 4. Analytics Service (Rust)
**Port**: 3003
**Technology**: Rust + Axum

Responsibilities:
- Real-time order analytics
- User behavior tracking
- Dashboard metrics
- Time-series data processing

## Communication

Services communicate via REST API over HTTP:

```
Go API → HTTP → Rust Services
```

Each request from Go API to Rust service includes:
- Authentication headers
- Service ID
- Request ID (for tracing)

## Project Structure

```
PiposmartPro/
├── backend/                    (Go - Main API)
│   ├── cmd/
│   ├── internal/
│   ├── Dockerfile
│   ├── go.mod
│   └── main.go
│
├── services/                   (Rust Microservices)
│   ├── image-service/
│   │   ├── src/
│   │   ├── Cargo.toml
│   │   └── Dockerfile
│   ├── report-service/
│   │   ├── src/
│   │   ├── Cargo.toml
│   │   └── Dockerfile
│   └── analytics-service/
│       ├── src/
│       ├── Cargo.toml
│       └── Dockerfile
│
├── frontend/                   (Flutter)
├── docker-compose.yml
├── docker-compose.hybrid.yml
└── HYBRID_ARCHITECTURE.md
```

## Running the Hybrid System

### With Docker Compose

```bash
# Run entire hybrid stack
docker-compose -f docker-compose.hybrid.yml up --build

# Services will be available at:
# - API Gateway: http://localhost:8080
# - Image Service: http://localhost:3001
# - Report Service: http://localhost:3002
# - Analytics Service: http://localhost:3003
```

### Local Development

#### Run Go Backend
```bash
cd backend
go run main.go
# API listens on :8080
```

#### Build Rust Services
```bash
# Build all services
cd services/image-service && cargo build --release
cd ../report-service && cargo build --release
cd ../analytics-service && cargo build --release

# Run individually
./target/release/piposmart-image-service
./target/release/piposmart-report-service
./target/release/piposmart-analytics-service
```

## Development Guidelines

### Go Backend
- Handle authentication & authorization
- Manage database transactions
- Coordinate between services
- API validation & error handling

### Rust Services
- Focus on performance-critical operations
- Minimal dependencies
- Strong type safety
- Zero-copy when possible

## API Contract Examples

### From Go to Image Service

```bash
POST http://localhost:3001/process
Content-Type: application/json
Authorization: Bearer <token>

{
  "image_path": "uploads/image.png",
  "operations": ["compress", "thumbnail"],
  "quality": 80
}
```

### From Go to Report Service

```bash
POST http://localhost:3002/generate
Content-Type: application/json
Authorization: Bearer <token>

{
  "report_type": "pdf",
  "data": { ... },
  "filters": { ... }
}
```

### From Go to Analytics Service

```bash
POST http://localhost:3003/track
Content-Type: application/json
Authorization: Bearer <token>

{
  "event": "order_completed",
  "user_id": "123",
  "data": { ... }
}
```

## Performance Considerations

### Why Rust for These Services?
1. **Image Processing**: Memory-efficient, fast operations
2. **Report Generation**: High throughput, concurrent requests
3. **Analytics**: Real-time data processing, low latency

### Benchmarks (Expected)
- Image Service: 100ms per image (average)
- Report Service: 500ms-2s per report
- Analytics Service: <50ms per event

## Deployment

### Production Docker Compose
```bash
docker-compose -f docker-compose.hybrid.yml \
  -f docker-compose.prod.yml \
  up -d
```

### Kubernetes (Future)
When scaling is needed:
- Go API: Horizontal scaling
- Rust Services: Independent scaling per service

## Monitoring

Each service exposes a `/health` endpoint:
```bash
curl http://localhost:8080/health     # Go API
curl http://localhost:3001/health     # Image Service
curl http://localhost:3002/health     # Report Service
curl http://localhost:3003/health     # Analytics Service
```

## Troubleshooting

### Service Connection Issues
1. Check Docker network: `docker network ls`
2. Verify service DNS: `docker exec <container> ping <service>`
3. Check ports: `netstat -tuln | grep -E '300[123]|8080'`

### Build Issues
- Rust: Ensure Rust 1.75+ installed
- Go: Ensure Go 1.21+ installed

## Future Enhancements

1. **gRPC Migration**: Replace REST with gRPC for better performance
2. **Message Queue**: Add RabbitMQ/Kafka for async operations
3. **Service Mesh**: Implement Istio for advanced routing
4. **API Gateway**: Kong or similar for rate limiting
5. **Observability**: Prometheus + Grafana for metrics

## Contributing

When adding new services:
1. Use Rust for CPU-intensive operations
2. Keep Go for orchestration & coordination
3. Update docker-compose.hybrid.yml
4. Document API contracts
5. Add health check endpoints

---

**Last Updated**: November 25, 2026
**Architecture Version**: 1.0
