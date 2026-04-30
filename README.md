# Docker Ollama

> **Author:** Ivan Simoy  
> *Powered by AI*

Ollama running in Docker with a configurable default model (see `.env`).

- Host port: configured via `OLLAMA_HOST_PORT` in `.env` (default Ollama port `11434` changed)
- API bound to `OLLAMA_HOST_BIND` in `.env` — set to `127.0.0.1` by default, not publicly exposed
- Model data stored in `./ollama_data/`
- Model auto-pulled on container start via `entrypoint.sh`

---

## Security

### API Key Authentication

Ollama supports a built-in API key via `OLLAMA_API_KEY`. When set, every request must include an `Authorization: Bearer` header — unauthenticated requests are rejected with `401`.

**Generate a key:**
```bash
./generate-api-key.sh
```

The script writes the key directly into `.env` and prints the value. Restart the container to apply:

```bash
docker-compose down && docker-compose up -d
```

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
| Behind a reverse proxy (nginx, Caddy) | Strongly recommended |
| Exposed to the internet | Required |

> The API key is stored only in `.env` which is gitignored and never committed.

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

If using a GPU, enable the NVIDIA GPU block in `docker-compose.yml` — see the GPU Support section below.

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
