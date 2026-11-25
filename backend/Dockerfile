# ---------- BUILD STAGE ----------
# Update versi ke 1.25 untuk menyesuaikan dengan go.mod kamu
FROM golang:1.25-bookworm AS builder

WORKDIR /app

# Install build dependencies untuk CGO dan pemrosesan gambar
RUN apt-get update && apt-get install -y \
    gcc \
    pkg-config \
    libwebp-dev \
    && rm -rf /var/lib/apt/lists/*

# CGO_ENABLED=1 diperlukan oleh library image processing (resize/webp)
ENV CGO_ENABLED=1

COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Build binary aplikasi
RUN go build -o app ./cmd/api

# ---------- RUNTIME STAGE ----------
FROM debian:bookworm-slim

# Install runtime dependencies (tzdata, wkhtmltopdf, dan library gambar)
RUN apt-get update && apt-get install -y \
    ca-certificates \
    tzdata \
    wkhtmltopdf \
    xfonts-75dpi \
    xfonts-base \
    libxrender1 \
    libjpeg62-turbo \
    libpng16-16 \
    libssl-dev \
    fontconfig \
    && rm -rf /var/lib/apt/lists/*

# Set zona waktu agar parameter loc=Local di DSN database akurat
ENV TZ=Asia/Jakarta

WORKDIR /app

# Ambil binary dari stage builder
COPY --from=builder /app/app ./app

# Siapkan struktur folder (uploads dan log akan di-mount via Docker Volume)
RUN mkdir -p /app/uploads /app/temp /app/log

# Salin aset statis dan template (PENTING: tambahkan assets jika ada icon sistem)
# COPY --from=builder /app/assets ./assets
COPY --from=builder /app/internal/templates ./internal/templates
COPY --from=builder /app/web ./web

EXPOSE 8080

# Jalankan aplikasi
CMD ["./app"]
