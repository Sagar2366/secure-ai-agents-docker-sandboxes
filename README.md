# Docker Sandboxes: A Hands-On Guide with the OpenTelemetry Demo

> **Status**: This guide covers the Docker Sandboxes `sbx` release as of its experimental launch.

---

## What you'll need

- An Anthropic API key (or Claude subscription)
- A GitHub account with a token that has permissions to push and pull
- macOS on Apple Silicon or Windows 11

## What you'll learn

By the end of this guide you'll be able to:

- Install and configure the `sbx` CLI
- Run an AI agent autonomously inside an isolated microVM sandbox
- Store credentials securely and have them injected automatically
- Use branch mode to let the agent work on its own Git branch
- Run Docker Compose inside the sandbox (private Docker daemon)
- Forward live ports from a sandbox to your browser
- Manage network policies so the agent can only reach what you allow
- Prove isolation: your host stays completely untouched

The guide uses the **OpenTelemetry Astronomy Shop** — a microservice-based
e-commerce system with 10+ services in Go, Python, TypeScript, C++, .NET, and
more. It runs via Docker Compose with Kafka, PostgreSQL, Redis, Prometheus,
Grafana, and Jaeger. Real-world complexity that justifies sandboxing.

---

## Table of contents

1. [How Docker Sandboxes work](#1-how-docker-sandboxes-work)
2. [Clone this repo](#2-clone-this-repo)
3. [Installation](#3-installation)
4. [Secrets and credentials](#4-secrets-and-credentials)
5. [Create your sandbox](#5-create-your-sandbox)
6. [Orient yourself](#6-orient-yourself)
7. [The interactive TUI dashboard](#7-the-interactive-tui-dashboard)
8. [Explore the architecture](#8-explore-the-architecture)
9. [Docker Compose inside the sandbox](#9-docker-compose-inside-the-sandbox)
10. [Port forwarding with `sbx ports`](#10-port-forwarding-with-sbx-ports)
11. [Network policies](#11-network-policies)
12. [Branch mode](#12-branch-mode)
13. [Attack simulation](#13-attack-simulation)
14. [Debugging with `sbx exec`](#14-debugging-with-sbx-exec)
15. [Appendix A: Prompt library](#appendix-a-prompt-library)
16. [Appendix B: CLI quick reference](#appendix-b-cli-quick-reference)

---

## 1. How Docker Sandboxes work

When you run `sbx run claude`, Docker Sandboxes:

1. Spins up a **lightweight microVM** — its own Linux kernel, not just a container namespace.
2. Gives the VM a **private Docker daemon**, so the agent can run `docker build` or `docker compose up` without touching your host Docker.
3. **Mounts your workspace directory** at its exact host path inside the VM. File changes are instant in both directions — no copy-on-write delay.
4. Routes all HTTP/HTTPS traffic from the VM through a **host-side proxy** that enforces your network policy and injects API credentials. The agent never sees raw credentials.
5. Starts the agent with autonomous permissions so it can act without prompting you on every file change.

The result: the agent can build images, install packages, run tests, and edit your code —
and none of that can escape the VM to touch your host system, your other containers,
or any network destination you haven't explicitly allowed.

```
Your machine
├── Host Docker daemon    ← your stuff, untouched
├── Host filesystem       ← workspace dir shared (read/write); nothing else
│
└── Sandbox (microVM)
    ├── Private Docker daemon  ← agent builds here
    ├── /your/workspace        ← live-mounted from host
    └── Outbound HTTP proxy    ← enforces network policy, injects creds
```

---

## 2. Clone this repo

```bash
git clone https://github.com/Sagar2366/secure-ai-agents-docker-sandboxes.git
cd secure-ai-agents-docker-sandboxes
```

The `opentelemetry-demo/` directory contains the full Astronomy Shop source code —
10+ microservices, Docker Compose files, and observability config.

---

## 3. Installation

> Docker Desktop is **not** required to run `sbx`

### macOS (Apple Silicon required)

```bash
brew install docker/tap/sbx
```

### Windows (x86_64, Windows 11 required)

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform -All
# Restart when prompted
winget install -h Docker.sbx
```

### Sign in

```bash
sbx login
```

### Set default network policy

On your first run the daemon prompts you to choose a network policy:

```
Choose a default network policy:

     1. Open         — All network traffic allowed, no restrictions.
     2. Balanced     — Default deny, with common dev sites allowed.
     3. Locked Down  — All network traffic blocked unless you allow it.

  Use ↑/↓ to navigate, Enter to select, or press 1–3.
```

Choose **Balanced** for this guide. It allows AI provider APIs, package managers,
Docker Hub, GitHub, and container registries out of the box.

---

## 4. Secrets and credentials

`sbx` has a built-in secrets manager that stores credentials in your OS keychain —
never in plain text on disk or inside the VM. When the agent makes an outbound request
that needs authentication, the host-side proxy intercepts it and injects the credential
automatically. The agent can make authenticated API calls but can never read, log, or
exfiltrate the raw credential.

```bash
# Store Anthropic API key (global — available to all sandboxes)
sbx secret set -g anthropic

# Store GitHub token
echo "$(gh auth token)" | sbx secret set -g github

# Verify
sbx secret ls
```

> **Important**: global secrets must be set before a sandbox is created. They are
> injected at creation time and cannot be added retroactively to a running sandbox.

### Supported services

| Service     | Environment variable(s)                       | API domain(s)                       |
|-------------|-----------------------------------------------|-------------------------------------|
| `anthropic` | `ANTHROPIC_API_KEY`                           | `api.anthropic.com`                 |
| `openai`    | `OPENAI_API_KEY`                              | `api.openai.com`                    |
| `github`    | `GH_TOKEN`, `GITHUB_TOKEN`                    | `api.github.com`, `github.com`      |
| `google`    | `GEMINI_API_KEY`, `GOOGLE_API_KEY`            | `generativelanguage.googleapis.com` |

---

## 5. Create your sandbox

```bash
cd opentelemetry-demo
sbx create claude --name otel-demo .
```

Confirm it was created:

```bash
sbx ls
```

Launch Claude Code inside the sandbox:

```bash
sbx run otel-demo
```

---

## 6. Orient yourself

Give Claude the following prompt:

```
Explore this codebase and give me:
1. A summary of the architecture and tech stack
2. List all microservices with their language and role
3. How to run it locally using Docker Compose
4. What observability tools are included (tracing, metrics, logs)
```

Claude will read compose files, source directories, and report back. Because the
workspace is mounted directly into the VM, the agent sees your actual files — including
any changes you make on the host while it's running.

### Controlling the session

- Press **`Ctrl-C` twice** to exit the session and drop back to your host terminal.

---

## 7. The interactive TUI dashboard

Running `sbx` with no arguments opens the TUI.

```bash
sbx
```

The dashboard shows all sandboxes as cards with live CPU and memory usage.

| Key     | Action                                               |
|---------|------------------------------------------------------|
| `c`     | Create a new sandbox                                 |
| `s`     | Start or stop the selected sandbox                   |
| `Enter` | Attach to the agent session (same as `sbx run`)      |
| `x`     | Open a shell inside the sandbox (`sbx exec`)         |
| `r`     | Remove the selected sandbox                          |
| `Tab`   | Switch between the Sandboxes panel and Network panel |
| `?`     | Show all shortcuts                                   |

The **Network panel** (press `Tab`) shows a live log of every outbound connection the
sandbox makes — which hosts were reached, which were blocked.

---

## 8. Explore the architecture

Reconnect to your sandbox:

```bash
sbx run otel-demo
```

Give Claude the following prompt:

```
Look at the recommendation service (src/recommendation/).
It's written in Python and uses gRPC. Explain:
1. What it does
2. How it's instrumented with OpenTelemetry
3. What traces/metrics it exports
4. Any improvements you'd suggest
```

> Claude will read the Python files, understand the gRPC service definition,
> and analyze the OTel instrumentation. This demonstrates the agent working
> with real production-style code.

---

## 9. Docker Compose inside the sandbox

Each sandbox has its own private Docker daemon. The agent can run `docker compose up`,
build images, and start containers — none of which appear in your host's `docker ps`.

Give Claude the following prompt:

```
Start the OpenTelemetry demo using Docker Compose.
Use `docker compose up -d` with the default compose.yaml.
Wait for services to be healthy, then:
1. Show running containers with `docker compose ps`
2. Confirm the frontend is accessible at localhost:8080
3. Confirm Jaeger UI is at localhost:16686
4. Report which services are healthy and which aren't
```

While Claude works, verify from your host:

```bash
# Your host Docker — completely empty
docker ps
# → Nothing

# But inside the sandbox:
sbx exec otel-demo -- docker ps
# → 15+ running containers (frontend, cart, checkout, kafka, postgres, etc.)
```

> The agent is running a full microservices platform with Kafka, Postgres, Redis,
> Prometheus, Grafana, Jaeger — but your host Docker is untouched. Two separate worlds.

---

## 10. Port forwarding with `sbx ports`

Sandboxes are network-isolated — your browser can't reach a server inside one by
default. `sbx ports` punches a hole from a host port to a sandbox port.

### Forward the Astronomy Shop frontend

```bash
sbx ports otel-demo --publish 8080:8080
```

Open `http://localhost:8080` — that's the live e-commerce frontend running inside the sandbox.

### Forward Jaeger (tracing UI)

```bash
sbx ports otel-demo --publish 16686:16686
```

Open `http://localhost:16686` — browse distributed traces from all services.

### Forward Grafana (dashboards)

```bash
sbx ports otel-demo --publish 3000:3000
```

### Check active ports

```bash
sbx ports otel-demo
```

### Stop forwarding

```bash
sbx ports otel-demo --unpublish 8080:8080
```

> **Gotcha**: services inside the sandbox must bind to `0.0.0.0`, not `127.0.0.1`.
> Published ports don't survive a sandbox stop/restart — re-run `sbx ports` after restarting.

---

## 11. Network policies

Every sandbox routes outbound HTTP/HTTPS through a host-side proxy that enforces
access rules you define.

| Policy      | Description                                                                          |
|-------------|--------------------------------------------------------------------------------------|
| Open        | All traffic allowed — no restrictions                                                |
| Balanced    | Default deny, with a broad allow-list covering AI APIs, Docker Hub, pip, npm, GitHub |
| Locked Down | Everything blocked; you explicitly allow what you need                               |

### Inspect current rules

```bash
sbx policy ls
```

### See what the sandbox is hitting

```bash
sbx policy log
```

### Allow additional hosts

```bash
sbx policy allow network "*.npmjs.org,*.pypi.org,files.pythonhosted.org"
```

### Block a host

```bash
sbx policy deny network ads.example.com
```

---

## 12. Branch mode

Branch mode gives the agent its own Git worktree and branch, isolated from your main
working tree. You keep working normally; the agent works on its branch; you review the
diff and merge when ready.

```bash
sbx run otel-demo --branch=improve-recommendation
```

Give Claude:

```
The recommendation service (src/recommendation/) currently picks products randomly.
Improve it to use a simple collaborative filtering approach:
- Track which products are frequently bought together
- Recommend products based on what's in the user's cart
Commit your changes with a descriptive message.
```

When done, review and push:

```bash
git diff main..improve-recommendation
git push origin improve-recommendation
```

---

## 13. Attack simulation

This section demonstrates what the sandbox blocks. The `exfil.sh` script simulates:
- Credential theft (reading ~/.aws, ~/.ssh)
- Data exfiltration to an external server
- C2 server callback
- Internal network scanning

### Run the attack inside a sandbox

```bash
sbx run shell
```

Inside the sandbox:

```bash
./exfil.sh
```

Expected output:

```
=== SIMULATED ATTACK ===
[1] Reading host credentials...
cat: /root/.aws/credentials: No such file or directory
cat: /root/.ssh/id_rsa: No such file or directory
[2] Exfiltrating .env to external server...
curl: (6) Could not resolve host: evil-server.attacker.com
[3] Pinging C2 server...
bash: ping: command not found
[4] Scanning internal network...
curl: (7) Failed to connect to 192.168.1.1 port 8080
=== ATTACK COMPLETE ===
```

Every blocked attempt is logged:

```bash
sbx policy log
```

### Layered defense

Even after installing tools (allowed — package managers are on the allowlist), the network policy still blocks:

```bash
apt-get install -y iputils-ping
ping -c 3 198.51.100.1
# → Network is unreachable
```

---

## 14. Debugging with `sbx exec`

`sbx exec` opens a shell inside a running sandbox. Run from your host terminal:

```bash
sbx exec -it otel-demo bash
```

From inside:

```bash
docker ps                    # what containers are running?
docker compose logs cart     # check cart service logs
curl localhost:8080          # is the frontend up?
```

Type `exit` to leave. The Claude session keeps running.

### One-off command

```bash
sbx exec -it otel-demo bash -c "docker compose ps --format 'table {{.Name}}\t{{.Status}}'"
```

---

## Appendix A: Prompt library

### Explore the codebase

```
Explore this repository and produce a technical overview covering:
1. Architecture and tech stack (list every microservice, its language, and role)
2. How data flows through the system end to end (user → frontend → backend services)
3. How to run the project with Docker Compose
4. What observability is configured (traces, metrics, logs)
5. The top 3 areas you'd investigate first if debugging a production incident
```

### Start the full stack

```
Start the OpenTelemetry demo with `docker compose up -d`.
Wait for services to be healthy, then confirm:
- Frontend at localhost:8080
- Jaeger at localhost:16686
- Grafana at localhost:3000
Report which services are up and which failed.
```

### Improve a service

```
The recommendation service (src/recommendation/) picks products randomly.
Improve it to recommend products based on the user's cart contents.
Use simple collaborative filtering. Run the tests after your changes.
Commit with a descriptive message.
```

### Add a health check endpoint

```
The frontend-proxy (src/frontend-proxy/) doesn't have a dedicated health endpoint.
Add a /health route that returns JSON with status and uptime.
Make sure it's included in the Docker healthcheck in compose.yaml.
```

### Fix observability gaps

```
Review the checkout service (src/checkout/) and identify any missing
OpenTelemetry instrumentation:
- Are all outbound gRPC calls traced?
- Are errors recorded as span events?
- Are there any untraced code paths?
Add the missing instrumentation and verify traces appear in Jaeger.
```

---

## Appendix B: CLI quick reference

```bash
# ── Lifecycle ──────────────────────────────────────────────────────────────────
sbx run --name=otel-demo kiro .          # create and attach to a named sandbox
sbx run otel-demo                        # reconnect to an existing sandbox
sbx run otel-demo --branch=my-feature    # branch mode
sbx create kiro .                        # create without attaching
sbx ls                                   # list sandboxes
sbx stop otel-demo                       # pause
sbx rm otel-demo                         # delete sandbox + VM

# ── Attach & shell ─────────────────────────────────────────────────────────────
sbx exec -it otel-demo bash              # shell inside sandbox
sbx exec -d otel-demo bash -c "cmd"      # one-off command

# ── Port forwarding ────────────────────────────────────────────────────────────
sbx ports otel-demo --publish 8080:8080  # host:8080 → sandbox:8080
sbx ports otel-demo                      # show active forwarding
sbx ports otel-demo --unpublish 8080:8080

# ── Network policies ───────────────────────────────────────────────────────────
sbx policy ls                            # list active rules
sbx policy log                           # show connection log
sbx policy allow network example.com     # allow a host
sbx policy deny network evil.com         # block a host

# ── Credentials ────────────────────────────────────────────────────────────────
sbx secret set -g github                 # store token globally
sbx secret ls                            # list stored secrets

# ── Dashboard ──────────────────────────────────────────────────────────────────
sbx                                      # open interactive TUI
```

---

## The 3Cs — Takeaway

| C | Principle | How |
|---|-----------|-----|
| **Contain** | Limit what agents reach | `sbx run` (microVM) |
| **Control** | Govern what agents do | Network + MCP policies |
| **Clarity** | See what agents did | `sbx policy log` |

---

*Sagar Utekar — Docker Captain | Senior SRE, CrowdStrike | CNCF Ambassador | @SagarUtekar*
