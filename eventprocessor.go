package eventprocessor

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"math/rand"
	"strconv"
	"strings"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/aws/aws-sdk-go-v2/service/sqs/types"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/arn"
	"golang.org/x/oauth2"
)

const retryAttribute = "Retries"

type EventProcessor struct {
	opts       *Options
	tokenCache *TokenCache
	sqs        SQSAPI
}

type Options struct {
	DelayMs        int
	ExpiresInHours int
	MaxRetries     int
	CalleeURL      string
	OAuth2Scope    string
}

type Event struct {
	Id        string    `json:"id"`
	Message   string    `json:"message"`
	CreatedAt time.Time `json:"createdAt"`
}

type SQSAPI interface {
	SendMessage(ctx context.Context, params *sqs.SendMessageInput, optFns ...func(*sqs.Options)) (*sqs.SendMessageOutput, error)
}

func New(opts *Options, tokenCache *TokenCache, sqs SQSAPI) (*EventProcessor, error) {
	return &EventProcessor{
		opts:       opts,
		tokenCache: tokenCache,
		sqs:        sqs,
	}, nil
}

func (ep *EventProcessor) Handle(ctx context.Context, sqsEvent events.SQSEvent) error {
	var event Event
	sqsMsg := sqsEvent.Records[0]
	if err := json.Unmarshal([]byte(sqsMsg.Body), &event); err != nil {
		return fmt.Errorf("unable to marshal event body to json: %w", err)
	}
	opts := ep.opts
	now := time.Now()
	if int(now.Sub(event.CreatedAt).Hours()) > opts.ExpiresInHours {
		return fmt.Errorf("event with id %s created at %s has expired as it is older than %d hours", event.Id, event.CreatedAt, opts.ExpiresInHours)
	}
	scopes := strings.Split(ep.opts.OAuth2Scope, " ")
	token, err := ep.tokenCache.GetToken(ctx, scopes...)
	if err != nil {
		return ep.handleError(ctx, err, sqsMsg, event)
	}
	err = simulateRequest(ep.opts.CalleeURL, event, token)
	if err != nil {
		return ep.handleError(ctx, err, sqsMsg, event)
	}
	log.Printf("processed event with id %s, sleeping for %vms", event.Id, opts.DelayMs)
	time.Sleep(time.Duration(opts.DelayMs) * time.Millisecond)
	log.Println("done")
	return nil
}

func (ep *EventProcessor) handleError(ctx context.Context, err error, sqsMsg events.SQSMessage, event Event) error {
	log.Println(err)
	opts := ep.opts
	retries := getRetryCount(sqsMsg) + 1
	if retries <= opts.MaxRetries {
		log.Printf("sending event with id %s back to source queue on attempt no. %d", event.Id, retries)
		return ep.retry(ctx, sqsMsg, opts.DelayMs, retries)
	}
	log.Printf("unable to process event with id %s, reached threshold of %d retries", event.Id, opts.MaxRetries)
	return err
}

func getRetryCount(sqsMsg events.SQSMessage) int {
	attr, ok := sqsMsg.MessageAttributes[retryAttribute]
	if !ok {
		return 0
	}
	retries, _ := strconv.Atoi(*attr.StringValue)
	return retries
}

func simulateRequest(url string, event Event, token *oauth2.Token) error {
	log.Printf("simulating request to %s using token with expiry %v", url, token.Expiry)
	max, min := 10, 3
	delayMs := (rand.Intn(max-min+1) + min) * 100
	time.Sleep(time.Duration(delayMs) * time.Millisecond)
	log.Printf("simulated request took %dms", delayMs)
	if event.Message == "error" {
		return errors.New("event error")
	}
	return nil
}

func (ep *EventProcessor) retry(ctx context.Context, sqsMsg events.SQSMessage, delayMs int, retries int) error {
	queueArn, _ := arn.Parse(sqsMsg.EventSourceARN)
	queueUrl := fmt.Sprintf("https://sqs.%s.amazonaws.com/%s/%s", queueArn.Region, queueArn.AccountID, queueArn.Resource)
	input := &sqs.SendMessageInput{
		DelaySeconds: int32(delayMs/1000) * int32(retries),
		MessageBody:  aws.String(sqsMsg.Body),
		QueueUrl:     aws.String(queueUrl),
		MessageAttributes: map[string]types.MessageAttributeValue{
			retryAttribute: {
				DataType:    aws.String("Number"),
				StringValue: aws.String(strconv.Itoa(retries)),
			},
		},
	}
	_, err := ep.sqs.SendMessage(ctx, input)
	if err != nil {
		return err
	}
	return nil
}

type TokenCache struct {
	tokenFunc func(ctx context.Context, scopes []string) (*oauth2.Token, error)
	cache     map[string]*oauth2.Token
}

func NewTokenCache(tokenFunc func(ctx context.Context, scopes []string) (*oauth2.Token, error)) *TokenCache {
	return &TokenCache{
		tokenFunc: tokenFunc,
		cache:     make(map[string]*oauth2.Token),
	}
}

func (tc *TokenCache) GetToken(ctx context.Context, scopes ...string) (*oauth2.Token, error) {
	scope := strings.Join(scopes, " ")
	expiryDelta := time.Duration(-10) * time.Second
	token := tc.cache[scope]
	if token != nil {
		expiry := token.Expiry.Add(expiryDelta)
		if time.Now().Before(expiry) {
			log.Printf("getting token from cache, expires at %v", expiry)
			return token, nil
		}
		log.Printf("token expired at %v", expiry)
	}
	log.Printf("getting new token with requested scope %s", scope)
	token, err := tc.tokenFunc(ctx, scopes)
	if err != nil {
		return nil, err
	}
	log.Printf("got new token, expires at %v", token.Expiry.Add(expiryDelta))
	tc.cache[scope] = token
	return token, nil
}
