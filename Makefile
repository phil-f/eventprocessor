build:
	GOOS=linux GOARCH=arm64 go build -o bootstrap cmd/eventprocessor/main.go
	zip eventprocessor.zip bootstrap

deploy:
	cd terraform; \
	terraform apply -auto-approve
