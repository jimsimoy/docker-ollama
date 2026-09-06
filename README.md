# Docker Ollama

<div align="center">

<img src="https://img.shields.io/badge/docker-compose-2496ED.svg?style=flat-square&logo=docker&logoColor=white" alt="Docker Compose">
<a href="https://github.com/jimsimoy/docker-ollama/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square" alt="License: MIT"></a>

**Ollama running in Docker with a configurable default model, a bearer-token auth gate, and support for both local and cloud models.**

by [Jan Ivan Simoy](https://github.com/jimsimoy)

</div>

---

## What is this?

A production-ready Docker Compose setup for self-hosting [Ollama](https://ollama.com) — an OpenAI-compatible LLM server. It's built for running behind a reverse proxy with a real auth gate rather than exposed raw, and supports switching between locally-run models and Ollama's cloud models (inference on Ollama's servers, no local GPU needed) via one `.env` variable.

---

## Features

| Feature | Detail |
|---|---|
| Configurable host port/bind | `OLLAMA_HOST_PORT` / `OLLAMA_HOST_BIND` in `.env` — bound to `127.0.0.1` by default, not publicly exposed |
| Model auto-pull | Default model in `.env` is pulled automatically on container start via `entrypoint.sh` |
| Cloud + local models | Switch with one `.env` variable — cloud models need no local GPU |
| API key auth | Generated with `generate-api-key.sh`, enforced at the reverse-proxy layer |
| Resource limits | CPU memory cap and GPU support (NVIDIA) both configurable |
| Health checks | Built into `docker-compose.yml` |

---

## Requirements

| Requirement | Notes |
|---|---|
| Docker + Docker Compose | Tested with the `version: '3.8'` compose syntax |
| Reverse proxy (recommended) | e.g. Nginx Proxy Manager, for the auth gate described below |
| NVIDIA driver + `nvidia-container-toolkit` | Only if running local (non-cloud) models with GPU acceleration |

---

## Setup

```bash
# Copy and configure environment
cp .env.example .env

# Edit .env — set OLLAMA_HOST_PORT, OLLAMA_MODEL, etc.

# Start the container (pulls configured model automatically)
docker-compose up -d
```

### First-time sign-in (required for cloud models)

```bash
docker exec -it ollama ollama signin
```

Open the URL shown in the browser, log in with your Ollama account. Only needed once — credentials are stored in `./ollama_data/`.

---

## Security

### API Key Authentication

Public access is secured at the reverse-proxy layer (e.g. Nginx Proxy Manager), not by `docker-ollama` runtime auth in this setup. A proxy host in front of this container uses an auth gate in its advanced config:

```nginx
if ($http_authorization != "Bearer <your-key>") { return 401; }
```

Requests without a matching bearer token are rejected with `401` before they reach Ollama.

**Generate a key:**
```bash
./generate-api-key.sh
```

The script writes the key directly into `.env` and prints the value. `OLLAMA_API_KEY` in `.env` is the canonical token reference used by the proxy's auth gate.

**Use the key in requests:**
```bash
curl http://${OLLAMA_HOST_BIND}:${OLLAMA_HOST_PORT}/api/chat \
  -H "Authorization: Bearer <your-key>" \
  -d '{"model": "${OLLAMA_MODEL}", "messages": [{"role": "user", "content": "Hello!"}], "stream": false}'
```

**With the Python `openai` library:**
```python
from openai import OpenAI

client = OpenAI(
    base_url="http://${OLLAMA_HOST_BIND}:${OLLAMA_HOST_PORT}/v1",
    api_key="<your-key>",
)
```

### When is the API key required?

| Setup | API key needed? |
|---|---|
| `OLLAMA_HOST_BIND=127.0.0.1` (local only) | Optional — no external access |
| Exposed to LAN (`0.0.0.0`) | Strongly recommended |
| Behind reverse proxy with auth gate | Required for public requests |
| Exposed to the internet | Required |

> The API key is stored in `.env` (gitignored). If you rotate the key in `.env`, update the proxy's auth gate value to match.

---

## Interactive Chat

```bash
docker exec -it ollama ollama run ${OLLAMA_MODEL}
```

Type your message and press Enter. Type `/bye` to exit.

---

## REST API

Base URL: `http://${OLLAMA_HOST_BIND}:${OLLAMA_HOST_PORT}`

**Chat (one-shot):**
```bash
curl http://${OLLAMA_HOST_BIND}:${OLLAMA_HOST_PORT}/api/chat \
  -d '{
    "model": "${OLLAMA_MODEL}",
    "messages": [{"role": "user", "content": "Hello!"}],
    "stream": false
  }'
```

**Chat with streaming:**
```bash
curl http://${OLLAMA_HOST_BIND}:${OLLAMA_HOST_PORT}/api/chat \
  -d '{
    "model": "${OLLAMA_MODEL}",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

**Single generate (no chat history):**
```bash
curl http://${OLLAMA_HOST_BIND}:${OLLAMA_HOST_PORT}/api/generate \
  -d '{"model": "${OLLAMA_MODEL}", "prompt": "Hello!", "stream": false}'
```

**OpenAI-compatible endpoint** (works with any OpenAI-compatible client):
```bash
curl http://${OLLAMA_HOST_BIND}:${OLLAMA_HOST_PORT}/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "${OLLAMA_MODEL}",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

Point the base URL to `http://${OLLAMA_HOST_BIND}:${OLLAMA_HOST_PORT}` in the Python `openai` library, LangChain, Continue.dev, or any OpenAI-compatible client.

---

## Model Management

```bash
# List installed models
docker exec ollama ollama list

# Pull a model
./pull-model.sh llama3.2:3b

# Remove a model
docker exec ollama ollama rm ${OLLAMA_MODEL}

# Show model info
docker exec ollama ollama show ${OLLAMA_MODEL}

# Check running models
docker exec ollama ollama ps
```

To change the default model, update `OLLAMA_MODEL` in `.env` and restart the container.

---

## Container Management

```bash
# Start
docker-compose up -d

# Stop
docker-compose down

# View logs
docker logs -f ollama

# Restart
docker-compose down && docker-compose up -d
```

---

## Switching Models

To use a different model, update `OLLAMA_MODEL` in `.env` and restart the container. The entrypoint script pulls it automatically on start.

```bash
# In .env
OLLAMA_MODEL=qwen3.6:27b

# Restart
docker-compose down && docker-compose up -d
```

### Cloud models vs Local models

| | Cloud (e.g. `kimi-k2:1t-cloud`) | Local (e.g. `qwen3.6:27b`) |
|---|---|---|
| Inference runs on | Provider's servers | This host |
| Download size | ~369 B (manifest only) | 17–70 GB |
| GPU required | No | Recommended |
| Works offline | No | Yes |
| Sign-in required | Yes (Ollama account) | No |

### Local model hardware requirements

Running a local model requires enough memory to hold the model weights. Without sufficient RAM or GPU VRAM the model offloads to disk, which makes it extremely slow (minutes per token).

**Example — `qwen3.6:27b` (17 GB, smallest variant):**

| Resource | Minimum | Recommended |
|---|---|---|
| Disk | 17 GB free | 25 GB+ |
| GPU VRAM | — | 20 GB+ (e.g. RTX 3090/4090, A100) |
| RAM (CPU-only, no GPU) | 32 GB | 64 GB |

If using a GPU, enable the NVIDIA GPU block in `docker-compose.yml` — see [GPU Support](#gpu-support-nvidia--local-models-only) below.

**Available `qwen3.6` tags:**

| Tag | Size | Notes |
|---|---|---|
| `qwen3.6:27b` | 17 GB | Smallest, good balance |
| `qwen3.6:35b-a3b` | 24 GB | MoE, more capable |
| `qwen3.6:27b-q8_0` | 30 GB | Higher quality |
| `qwen3.6:27b-coding-*` | 20–31 GB | Code-optimized variants |

Full tag list: https://ollama.com/library/qwen3.6/tags

---

## GPU Support (NVIDIA) — Local Models Only

> Cloud models (e.g. `kimi-k2:1t-cloud`) run inference on the provider's servers and do **not** require a GPU on this host. GPU is only needed when running local models (e.g. `llama3.2:3b`, `mistral:7b`).

Requirements:
1. NVIDIA driver installed on the host
2. `nvidia-container-toolkit` installed — https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html
3. Docker daemon configured for the nvidia runtime

Then in `docker-compose.yml`, uncomment:
```yaml
runtime: nvidia
environment:
  - NVIDIA_VISIBLE_DEVICES=all
  - NVIDIA_DRIVER_CAPABILITIES=compute,utility
```

And in `.env`, uncomment:
```
NVIDIA_VISIBLE_DEVICES=all
```

---

## Project Structure

```
docker-compose.yml     # Service definition, resource limits, healthcheck
entrypoint.sh           # Auto-pulls the configured model on container start
generate-api-key.sh     # Generates and writes OLLAMA_API_KEY into .env
pull-model.sh           # Pulls an additional model on demand
.env.example            # Config template
```

---

## License

[MIT](./LICENSE) — free to use, modify, and distribute.

---

<div align="center">

[Report a Bug](https://github.com/jimsimoy/docker-ollama/issues) · [Request a Feature](https://github.com/jimsimoy/docker-ollama/issues)

</div>
