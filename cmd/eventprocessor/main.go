package main

import (
	"eventprocessor"
	"eventprocessor/cmd/eventprocessor/app"

	"github.com/aws/aws-lambda-go/lambda"
)

var processor *eventprocessor.EventProcessor

func init() {
	processor = app.NewEventProcessor()
}

func main() {
	lambda.Start(processor.Handle)
}
