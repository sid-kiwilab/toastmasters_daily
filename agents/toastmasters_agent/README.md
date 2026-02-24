# Toastmasters Agent (Cloud Run)

LangGraph chat agent with streaming for **toastmasters-daily**.

## Setup

- **env.yaml** must be YAML map format (same as kiwilab_functions), e.g.:
  ```yaml
  OPENAI_API_KEY: "sk-proj-your-key-here"
  ```
  Copy `env.yaml.example` → `env.yaml`, set your key. `env.yaml` is gitignored.
- **Deploy:** gcloud uses it via `--env-vars-file=env.yaml`.
- **Local Docker:** mount with `-v "%CD%\env.yaml:/app/env.yaml"`.  
  **Windows:** if the mount fails, use `-e OPENAI_API_KEY=your-key-here` instead.

## Local (Docker)

From `agents/toastmasters_agent`:

```cmd
docker build -t toastmasters-agent .
docker run -p 8080:8080 -v "%CD%\env.yaml:/app/env.yaml" toastmasters-agent
```

Or with uvicorn (set `OPENAI_API_KEY` in your shell first):

```cmd
pip install -r requirements.txt
uvicorn app:app --host 0.0.0.0 --port 8080
```

## Deploy

From `agents/toastmasters_agent`:

```cmd
gcloud config set project toastmasters-daily
gcloud run deploy toastmasters-agent --source . --project toastmasters-daily --region us-central1 --env-vars-file=env.yaml --allow-unauthenticated
```

**Concurrency and cold start**
- The Firebase pinger (every 5 min) keeps one instance warm, so the first request after a ping usually hits a warm instance and gets fast time-to-first-token (TTFT).
- **Higher concurrency** (e.g. `--concurrency 20`) lets that warm instance serve more concurrent chats, so more users get fast TTFT without spinning new instances. Default is 80; for this streaming app 10–20 is a good balance (avoids memory pressure per instance).
- **Guarantee no cold start:** use `--min-instances 1` so one instance is always up (higher cost). Then concurrency controls how many requests that instance handles before scaling out.

Example with optional flags:

```cmd
gcloud run deploy toastmasters-agent --source . --project toastmasters-daily --region us-central1 --env-vars-file=env.yaml --allow-unauthenticated --concurrency 20 --min-instances 0
```

(`--min-instances 0` is default; omit or set to 1 to keep one instance always warm.)

## API

| Path   | Method | Description |
|--------|--------|-------------|
| `/chat` | POST  | Body: `{ "message": "...", "history": [], "stream": true }`. `stream: true` → SSE; `stream: false` → JSON `{ "response": "..." }`. |
