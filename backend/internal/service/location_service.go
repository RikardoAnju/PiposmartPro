package service

import (
	"encoding/json"
	"fmt"
	"net/http"
)

type LocationService struct {
	baseUrl string
}

func NewLocationService() *LocationService {
	return &LocationService{
		// API publik wilayah.id (tanpa API Key untuk versi dasar)
		baseUrl: "https://www.wilayah.id/api",
	}
}

func (s *LocationService) GetProvinces() (interface{}, error) {
	url := fmt.Sprintf("%s/provinces.json", s.baseUrl)
	return s.makeRequest(url)
}

func (s *LocationService) GetCities(provinceID string) (interface{}, error) {
	url := fmt.Sprintf("%s/regencies/%s.json", s.baseUrl, provinceID)
	return s.makeRequest(url)
}

func (s *LocationService) GetDistricts(cityID string) (interface{}, error) {
	url := fmt.Sprintf("%s/districts/%s.json", s.baseUrl, cityID)
	return s.makeRequest(url)
}

func (s *LocationService) makeRequest(url string) (interface{}, error) {
	res, err := http.Get(url)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()

	var result map[string]interface{}
	if err := json.NewDecoder(res.Body).Decode(&result); err != nil {
		return nil, err
	}

	// wilayah.id biasanya mengembalikan data dalam field 'data'
	if data, ok := result["data"]; ok {
		return data, nil
	}
	
	return nil, fmt.Errorf("data wilayah tidak ditemukan")
}