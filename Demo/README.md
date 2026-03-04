# Mixi2 Demo

A command-line app that connects to the mixi2 API and prints incoming events to stdout.

## Prerequisites

- Swift 6.0+
- A mixi2 application with **Client Credentials** enabled
  - Client ID and Client Secret
  - Token endpoint URL
  - API hostname

## Environment variables

| Variable | Required | Description |
|---|---|---|
| `MIXI2_API_HOST` | Yes | gRPC API hostname (e.g. `api.mixi2.com`) |
| `MIXI2_CLIENT_ID` | Yes | OAuth2 client ID |
| `MIXI2_CLIENT_SECRET` | Yes | OAuth2 client secret |
| `MIXI2_TOKEN_URL` | Yes | OAuth2 token endpoint (e.g. `https://auth.mixi2.com/oauth/token`) |
| `MIXI2_API_PORT` | No | gRPC port (default: `443`) |
| `MIXI2_AUTH_KEY` | No | Value for the `x-auth-key` request header, if required |

## Run

Edit `run.sh` and fill in your credentials, then:

```sh
./Demo/run.sh
```

The script validates that all required variables are set before building and running. Press **Ctrl-C** to stop.

## What it does

1. Reads configuration from environment variables via `swift-configuration`.
2. Opens a gRPC connection to the API host.
3. Subscribes to the event stream and prints each event as it arrives (PING events are filtered automatically).
4. Reconnects with exponential backoff (1 s / 2 s / 4 s, up to 3 retries) on connection failure.
