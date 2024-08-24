package main

import (
	"bufio"
	"bytes"
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/user"
	"path/filepath"
	"regexp"
	"time"

	_ "github.com/mattn/go-sqlite3"
	"gopkg.in/yaml.v3"
)

type WebhookPayload struct {
	EventName  string `json:"event_name"`
	Username   string `json:"username"`
	ActionType string `json:"action_type"`
	Status     string `json:"status"`
}

type LogInfo struct {
	EventName  string
	Username   string
	ActionType string
	Status     string
}

const (
	interval = 30 * time.Second
)

type Config struct {
	Clients []struct {
		WebhookURLs []string `yaml:"webhook_urls"`
	} `yaml:"clients"`

	Targets []struct {
		Filter      string   `yaml:"filter"`
		Application string   `yaml:"application"`
		Paths       []string `yaml:"paths"`
	} `yaml:"targets"`

	Interval string `yaml:"interval"`
}

func initDB() (*sql.DB, error) {
	dbPath := "/var/lib/telex/file_monitor.db"
	err := os.MkdirAll("/var/lib/telex", 0755)
	if err != nil {
		return nil, fmt.Errorf("failed to create directory: %v", err)
	}

	db, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %v", err)
	}

	query := `
	CREATE TABLE IF NOT EXISTS file_mod_times (
		file_path TEXT PRIMARY KEY,
		last_mod_time DATETIME,
		last_offset INTEGER
	);`
	_, err = db.Exec(query)
	if err != nil {
		return nil, fmt.Errorf("failed to create table: %v", err)
	}

	return db, nil
}

func (li LogInfo) ToWebhookPayload() WebhookPayload {
	return WebhookPayload{
		EventName:  li.EventName,
		Username:   li.Username,
		ActionType: li.ActionType,
		Status:     li.Status,
	}
}

func main() {
	db, err := initDB()
	if err != nil {
		log.Fatalf("Error initializing database: %v", err)
	}
	defer db.Close()

	filePath := "/etc/telex/config.yaml"
	content, err := os.ReadFile(filePath)
	if err != nil {
		log.Fatalf("Error reading file: %v", err)
	}

	config := Config{}
	err = yaml.Unmarshal(content, &config)
	if err != nil {
		log.Fatalf("Error unmarshalling YAML: %v", err)
	}

	interval, err := time.ParseDuration(config.Interval)
	if err != nil {
		log.Fatalf("Error parsing interval: %v", err)
	}

	for _, target := range config.Targets {
		for _, path := range target.Paths {
			matchedFiles, err := filepath.Glob(path)
			if err != nil {
				log.Printf("Error with glob pattern: %v", err)
				continue
			}

			filterRegex, err := regexp.Compile(target.Filter)
			if err != nil {
				log.Printf("Error compiling regex filter: %v", err)
				continue
			}

			for _, matchedFile := range matchedFiles {
				go monitorLogFile(db, matchedFile, config.Clients[0].WebhookURLs, target.Application, filterRegex, interval)
			}
		}
	}

	select {}
}

func monitorLogFile(db *sql.DB, filePath string, webhookURLs []string, application string, filterRegex *regexp.Regexp, interval time.Duration) {
	var lastOffset int64 = 0
	var lastModTime time.Time

	currentUser, err := user.Current()
	if err != nil {
		log.Printf("Error getting current user: %v", err)
		return
	}

	err = db.QueryRow("SELECT last_mod_time, last_offset FROM file_mod_times WHERE file_path = ?", filePath).Scan(&lastModTime, &lastOffset)
	if err != nil && err != sql.ErrNoRows {
		log.Printf("Error querying last modification time and offset: %v", err)
		return
	}

	for {
		fileInfo, err := os.Stat(filePath)
		if err != nil {
			log.Printf("Error getting file info: %v", err)
			time.Sleep(interval)
			continue
		}

		if fileInfo.ModTime().After(lastModTime) {
			lastModTime = fileInfo.ModTime()

			file, err := os.Open(filePath)
			if err != nil {
				log.Printf("Error opening log file: %v", err)
				time.Sleep(interval)
				continue
			}

			_, err = file.Seek(lastOffset, io.SeekStart)
			if err != nil {
				log.Printf("Error seeking to last offset: %v", err)
				file.Close()
				time.Sleep(interval)
				continue
			}

			scanner := bufio.NewScanner(file)
			for scanner.Scan() {
				logEntry := scanner.Text()

				if !filterRegex.MatchString(logEntry) {
					continue
				}

				logInfo := parseLogEntry(logEntry, application, currentUser.Username, "error")

				for _, webhookURL := range webhookURLs {
					err = sendToWebhook(webhookURL, logInfo)
					if err != nil {
						log.Printf("Error sending log entry to webhook: %v", err)
					}
				}
			}

			if err := scanner.Err(); err != nil {
				log.Printf("Error reading log file: %v", err)
			}

			lastOffset, _ = file.Seek(0, io.SeekCurrent)
			file.Close()

			_, err = db.Exec("INSERT OR REPLACE INTO file_mod_times (file_path, last_mod_time, last_offset) VALUES (?, ?, ?)", filePath, lastModTime, lastOffset)
			if err != nil {
				log.Printf("Error updating last modification time and offset: %v", err)
			}
		}

		time.Sleep(interval)
	}
}

func parseLogEntry(logEntry, application, username, status string) LogInfo {
	return LogInfo{
		EventName:  application,
		Username:   username,
		ActionType: logEntry,
		Status:     status,
	}
}

func sendToWebhook(webhookURL string, logInfo LogInfo) error {
	payload := logInfo.ToWebhookPayload()

	data, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	req, err := http.NewRequest("POST", webhookURL, bytes.NewBuffer(data))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("received non-200 response code: %d", resp.StatusCode)
	}

	return nil
}
