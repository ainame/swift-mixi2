.PHONY: generate update-proto build test format clean

generate:
	git submodule update --init --recursive
	rm -rf Sources/Mixi2GRPC/Generated
	mkdir -p Sources/Mixi2GRPC/Generated
	bash scripts/patch_swift_prefix.sh
	buf generate
	git -C vendor/mixi2-api checkout -- .
	ruby scripts/generate_event_message_extensions.rb

update-proto:
	git submodule update --init --recursive --remote vendor/mixi2-api

build:
	swift build

test:
	swift test

format:
	swift package plugin --allow-writing-to-package-directory swiftformat -- --exclude "**/Generated" Sources Demo/*/Sources Tests

clean:
	rm -rf .build
