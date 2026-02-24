# Toastmasters Agent (Cloud Run)

LangGraph chat agent with streaming for **toastmasters-daily**.

## Setup

- Copy `env.yaml.example` → `env.yaml`, set `OPENAI_API_KEY`. `env.yaml` is gitignored.
- **Deploy:** gcloud uses it via `--env-vars-file=env.yaml`.
- **Local Docker:** mount it so the app can read it: `-v "%CD%\env.yaml:/app/env.yaml"`.  
  **Windows:** the volume mount often fails; pass the key with `-e` instead:  
  `docker run -p 8080:8080 -e OPENAI_API_KEY=your-key-here toastmasters-agent`

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
gcloud run deploy toastmasters-agent --source . --project toastmasters-daily --region us-central1 --env-vars-file=env.yaml --allow-unauthenticated
```

## API

| Path   | Method | Description |
|--------|--------|-------------|
| `/chat` | POST  | Body: `{ "message": "...", "history": [], "stream": true }`. `stream: true` → SSE; `stream: false` → JSON `{ "response": "..." }`. |
