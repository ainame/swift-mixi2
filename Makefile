.PHONY: generate build test clean

PROTO_DIR := /Users/satoshi.namai.01.ts/ghq/github.com/mixigroup/mixi2-api/proto

generate:
	rm -rf Sources/Mixi2GRPC/Generated
	mkdir -p Sources/Mixi2GRPC/Generated
	buf generate
	ruby scripts/generate_event_message_extensions.rb

build:
	swift build

test:
	swift test

clean:
	rm -rf .build
