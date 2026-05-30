# Project Guidance

## What This Repo Is

A hands-on guide for Docker Sandboxes (`sbx`), using the **OpenTelemetry Astronomy Shop** — a microservice-based e-commerce system — as the exercise app. The guide lives in `README.md`.

## Reference Documentation

Official Docker Sandboxes docs: **https://docs.docker.com/ai/sandboxes/**

Key sub-pages:
- Get started / usage
- Agents (claude-code, codex, copilot, gemini, docker-agent, kiro, opencode, custom-environments)
- Architecture, security, credentials
- Troubleshooting / FAQ

## Key sbx CLI Facts

- `sbx create` requires explicit workspace path: `sbx create --name=foo claude .`
- `sbx run` infers current dir: `sbx run claude` or reconnect with `sbx run <sandbox-name>`
- Worktrees stored at `.sbx/<sandbox-name>-worktrees/<branch>/`
- `sbx policy deny` — valid (allow, deny, log, ls, reset, rm, set-default)
- Global secrets inject at creation time; sandbox-scoped secrets inject immediately
- Services must bind to `0.0.0.0` (not `127.0.0.1`) for port forwarding to work
- `host.docker.internal` to reach host services from inside sandbox

---

# OpenTelemetry Astronomy Shop

A microservice-based distributed system demonstrating OpenTelemetry instrumentation.

## Stack

- **Services**: 10+ microservices (Go, Python, TypeScript, C#, C++, Java, Elixir)
- **Infrastructure**: Docker Compose, Kafka, PostgreSQL, Redis
- **Observability**: OpenTelemetry Collector, Prometheus, Grafana, Jaeger

## Quick start

```bash
cd opentelemetry-demo
docker compose up -d
```

| UI | URL |
|----|-----|
| Astronomy Shop (frontend) | http://localhost:8080 |
| Jaeger (tracing) | http://localhost:16686 |
| Grafana (dashboards) | http://localhost:3000 |
| Prometheus (metrics) | http://localhost:9090 |

## Key services

| Service | Language | Role |
|---------|----------|------|
| frontend | TypeScript | Next.js web UI |
| cart | C# | Shopping cart (Redis-backed) |
| checkout | Go | Order processing |
| payment | JavaScript | Payment simulation |
| recommendation | Python | Product recommendations (gRPC) |
| product-catalog | Go | Product data |
| currency | C++ | Currency conversion |
| email | Ruby | Order confirmation emails |
| shipping | Rust | Shipping cost calculation |
| ad | Java | Advertisement service |
| fraud-detection | Kotlin | Fraud scoring |

## Project structure

```
opentelemetry-demo/
├── src/
│   ├── frontend/          # Next.js (TypeScript)
│   ├── cart/              # .NET (C#)
│   ├── checkout/          # Go
│   ├── recommendation/    # Python (gRPC)
│   ├── product-catalog/   # Go
│   ├── currency/          # C++
│   ├── payment/           # JavaScript
│   ├── shipping/          # Rust
│   ├── ad/                # Java (Spring)
│   ├── fraud-detection/   # Kotlin
│   └── ...
├── compose.yaml           # Main compose file
├── compose.observability.yaml
├── otel-config.yml        # Collector configuration
└── pb/                    # Protocol buffer definitions
```
