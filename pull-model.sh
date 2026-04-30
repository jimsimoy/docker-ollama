#!/bin/bash
set -euo pipefail

MODEL="${1:-}"

if [ -z "$MODEL" ]; then
    echo "Usage: $0 <model-name>"
    echo ""
    echo "Examples:"
    echo "  $0 llama3.2:3b"
    echo "  $0 mistral:7b"
    echo "  $0 kimi-k2"
    echo ""
    echo "Available models: https://ollama.com/library"
    exit 1
fi

if ! docker ps --filter "name=ollama" --filter "status=running" --format '{{.Names}}' | grep -q "^ollama$"; then
    echo "ERROR: 'ollama' container is not running. Start it first with:"
    echo "  docker-compose up -d"
    exit 1
fi

echo "Pulling model: $MODEL"
docker exec -it ollama ollama pull "$MODEL"
echo ""
echo "Done. Run the model with:"
echo "  docker exec -it ollama ollama run $MODEL"
