package app

import (
	"context"
	"encoding/json"
	"eventprocessor"
	"fmt"
	"os"
	"strconv"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/aws/aws-secretsmanager-caching-go/secretcache"
	"golang.org/x/oauth2"
	"golang.org/x/oauth2/clientcredentials"
)

func NewEventProcessor() *eventprocessor.EventProcessor {
	p, err := newEventProcessor()
	if err != nil {
		panic(fmt.Errorf("unable to start app: %w", err))
	}
	return p
}

func newEventProcessor() (*eventprocessor.EventProcessor, error) {
	cfg, err := getConfig()
	if err != nil {
		return nil, err
	}
	secretCache, err := secretcache.New()
	if err != nil {
		return nil, err
	}
	tokenFunc := func(ctx context.Context, scopes []string) (*oauth2.Token, error) {
		s, err := secretCache.GetSecretStringWithContext(ctx, cfg.OAuth2SecretName)
		if err != nil {
			return nil, err
		}
		var creds *OAuth2Credentials
		if err := json.Unmarshal([]byte(s), &creds); err != nil {
			return nil, err
		}
		cfg := &clientcredentials.Config{
			ClientID:     creds.ClientID,
			ClientSecret: creds.ClientSecret,
			TokenURL:     cfg.OAuth2TokenURL,
			Scopes:       scopes,
		}
		return cfg.Token(ctx)
	}
	tokenCache := eventprocessor.NewTokenCache(tokenFunc)
	awsCfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		return nil, err
	}
	sqsClient := sqs.NewFromConfig(awsCfg)
	opts := &eventprocessor.Options{
		DelayMs:        cfg.DelayMs,
		ExpiresInHours: cfg.ExpiresInHours,
		MaxRetries:     cfg.MaxRetries,
		CalleeURL:      cfg.CalleeURL,
		OAuth2Scope:    cfg.OAuth2Scope,
	}
	processor, err := eventprocessor.New(opts, tokenCache, sqsClient)
	if err != nil {
		return nil, err
	}
	return processor, nil
}

type OAuth2Credentials struct {
	ClientID     string `json:"clientId"`
	ClientSecret string `json:"clientSecret"`
}

type Config struct {
	DelayMs          int
	ExpiresInHours   int
	MaxRetries       int
	CalleeURL        string
	OAuth2Scope      string
	OAuth2SecretName string
	OAuth2TokenURL   string
}

func getConfig() (*Config, error) {
	getError := func(envKey string, err error) error {
		return fmt.Errorf("unable to get env var with key %s: %w", envKey, err)
	}
	delayKey := "DELAY_MS"
	delay, err := strconv.Atoi(os.Getenv(delayKey))
	if err != nil {
		return nil, getError(delayKey, err)
	}
	expiresKey := "EXPIRES_IN_HOURS"
	expires, err := strconv.Atoi(os.Getenv(expiresKey))
	if err != nil {
		return nil, getError(expiresKey, err)
	}
	retriesKey := "MAX_RETRIES"
	maxRetries, err := strconv.Atoi(os.Getenv(retriesKey))
	if err != nil {
		return nil, getError(retriesKey, err)
	}
	return &Config{
		DelayMs:          delay,
		ExpiresInHours:   expires,
		MaxRetries:       maxRetries,
		CalleeURL:        os.Getenv("CALLEE_URL"),
		OAuth2TokenURL:   os.Getenv("OAUTH2_TOKEN_URL"),
		OAuth2Scope:      os.Getenv("OAUTH2_SCOPE"),
		OAuth2SecretName: os.Getenv("OAUTH2_SECRET_NAME"),
	}, nil
}
