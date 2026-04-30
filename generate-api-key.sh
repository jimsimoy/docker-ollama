#!/bin/bash
set -euo pipefail

ENV_FILE="$(dirname "$0")/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: .env file not found. Copy .env.example to .env first."
    exit 1
fi

# Generate a secure 32-byte hex key
NEW_KEY="$(openssl rand -hex 32)"

# Replace or insert OLLAMA_API_KEY in .env
if grep -q "^OLLAMA_API_KEY=" "$ENV_FILE"; then
    sed -i "s|^OLLAMA_API_KEY=.*|OLLAMA_API_KEY=${NEW_KEY}|" "$ENV_FILE"
else
    echo "OLLAMA_API_KEY=${NEW_KEY}" >> "$ENV_FILE"
fi

echo "API key generated and saved to .env"
echo ""
echo "  OLLAMA_API_KEY=${NEW_KEY}"
echo ""
echo "Restart the container to apply:"
echo "  docker-compose down && docker-compose up -d"
echo ""
echo "Use the key in requests:"
echo "  curl http://\${OLLAMA_HOST_BIND}:\${OLLAMA_HOST_PORT}/api/chat \\"
echo "    -H \"Authorization: Bearer ${NEW_KEY}\" \\"
echo "    -d '{\"model\": \"...\", \"messages\": [...]}'"
