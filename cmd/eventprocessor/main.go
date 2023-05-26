package main

import (
	"eventprocessor/cmd/eventprocessor/app"

	"github.com/aws/aws-lambda-go/lambda"
)

var processor = app.NewEventProcessor()

func main() {
	lambda.Start(processor.Handle)
}
