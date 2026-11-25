package utils

import (
	"mime/multipart"
	"strconv"
	"strings"
)

func ToFloat64(s string) float64 {
	f, err := strconv.ParseFloat(s, 64)
	if err != nil {
		return 0
	}
	return f
}

// SaveUploadedFile menangani penyimpanan file dengan kompresi otomatis
func SaveUploadedFile(file *multipart.FileHeader, subFolder string) (string, error) {
	uploadedPath, err := SaveCompressedImage(file, ImageUploadOptions{
		SubFolder: subFolder,
		Prefix:    subFolder,
		MaxWidth:  1000,
		Quality:   75,
	})
	if err != nil {
		return "", err
	}

	return strings.TrimPrefix(uploadedPath, "/uploads/"), nil
}
