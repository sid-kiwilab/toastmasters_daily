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

## API

| Path   | Method | Description |
|--------|--------|-------------|
| `/chat` | POST  | Body: `{ "message": "...", "history": [], "stream": true }`. `stream: true` → SSE; `stream: false` → JSON `{ "response": "..." }`. |
