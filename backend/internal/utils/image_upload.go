package utils

import (
	"bytes"
	"fmt"
	"mime/multipart"
	"path"
	"strings"
	"time"

	"github.com/chai2010/webp"
	"github.com/disintegration/imaging"
)

type ImageUploadOptions struct {
	SubFolder string
	Prefix    string
	MaxWidth  int
	Quality   int
	Format    string
}

func SaveCompressedImage(file *multipart.FileHeader, opts ImageUploadOptions) (string, error) {
	if file == nil {
		return "", fmt.Errorf("file gambar tidak ditemukan")
	}

	subFolder := strings.Trim(opts.SubFolder, "/")
	if subFolder == "" {
		return "", fmt.Errorf("folder upload wajib diisi")
	}

	maxWidth := opts.MaxWidth
	if maxWidth <= 0 {
		maxWidth = 1000
	}

	quality := opts.Quality
	if quality <= 0 || quality > 100 {
		quality = 75
	}

	prefix := strings.TrimSpace(opts.Prefix)
	if prefix == "" {
		prefix = "img"
	}

	outputFormat := strings.ToLower(strings.TrimSpace(opts.Format))
	if outputFormat == "" {
		outputFormat = "webp"
	}

	src, err := file.Open()
	if err != nil {
		return "", err
	}
	defer src.Close()

	img, err := imaging.Decode(src, imaging.AutoOrientation(true))
	if err != nil {
		return "", fmt.Errorf("format file tidak didukung")
	}

	if img.Bounds().Dx() > maxWidth {
		img = imaging.Resize(img, maxWidth, 0, imaging.Lanczos)
	}

	fileExt := ".jpg"
	contentType := "image/jpeg"
	if outputFormat == "webp" {
		fileExt = ".webp"
		contentType = "image/webp"
	}

	fileName := fmt.Sprintf("%s_%d%s", prefix, time.Now().UnixNano(), fileExt)
	objectKey := path.Join(subFolder, fileName)

	var buf bytes.Buffer
	switch outputFormat {
	case "webp":
		if err := webp.Encode(&buf, img, &webp.Options{Quality: float32(quality)}); err != nil {
			return "", fmt.Errorf("gagal memproses gambar")
		}
	default:
		if err := imaging.Encode(&buf, img, imaging.JPEG, imaging.JPEGQuality(quality)); err != nil {
			return "", fmt.Errorf("gagal memproses gambar")
		}
	}

	return SaveUploadBytes(objectKey, buf.Bytes(), contentType)
}
