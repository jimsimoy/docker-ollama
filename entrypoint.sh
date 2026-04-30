#!/bin/bash
set -euo pipefail

# Start Ollama server in the background
ollama serve &
OLLAMA_PID=$!

# Wait until the API is accepting connections
echo "Waiting for Ollama to start..."
until curl -sf http://localhost:11434/ > /dev/null 2>&1; do
    sleep 1
done
echo "Ollama is ready."

# Pull the configured model if set
if [ -n "${OLLAMA_MODEL:-}" ]; then
    echo "Pulling model: ${OLLAMA_MODEL}"
    ollama pull "${OLLAMA_MODEL}" || echo "WARNING: Failed to pull model '${OLLAMA_MODEL}' — it can be pulled manually later."
fi

# Hand control back to the Ollama process
wait $OLLAMA_PID
