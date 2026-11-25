package utils

import (
	"regexp"
	"strings"
)

var (
	notificationUnsafeChars = regexp.MustCompile(`[^\p{L}\p{N}\s.,:;!?/@+_'()&%-]`)
	notificationWhitespace  = regexp.MustCompile(`\s+`)
)

func CleanNotificationText(input, fallback string) string {
	cleaned := notificationUnsafeChars.ReplaceAllString(input, "")
	cleaned = notificationWhitespace.ReplaceAllString(cleaned, " ")
	cleaned = strings.TrimSpace(cleaned)
	if cleaned == "" {
		return fallback
	}
	return cleaned
}
