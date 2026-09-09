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
gcloud run deploy toastmasters-agent --source . --project toastmasters-daily --region us-central1 --env-vars-file=env.yaml --allow-unauthenticated --concurrency 20 --min-instances 0
```

**Concurrency and cold start**
- The Firebase pinger (every 5 min) keeps one instance warm, so the first request after a ping usually hits a warm instance and gets fast time-to-first-token (TTFT).
- **Higher concurrency** (e.g. `--concurrency 20`) lets that warm instance serve more concurrent chats, so more users get fast TTFT without spinning new instances. Default is 80; for this streaming app 10–20 is a good balance (avoids memory pressure per instance).
- **Guarantee no cold start:** use `--min-instances 1` so one instance is always up (higher cost). Then concurrency controls how many requests that instance handles before scaling out.

Example with optional flags:

(`--min-instances 0` is default; omit or set to 1 to keep one instance always warm.)

## API

| Path   | Method | Description |
|--------|--------|-------------|
| `/chat` | POST  | Body: `{ "message": "...", "history": [], "stream": true, "location": "optional place name", "lat": -36.89, "lng": 174.91 }`. GPS is used for "near me"; a named city is geocoded instead. `find_nearby_clubs` returns signed-up clubs within ~80 km, else official TI clubs via web search. `stream: true` → SSE; `stream: false` → JSON `{ "response": "..." }`. |

## Seed demo clubs (NZ)

From `agents/toastmasters_agent` (requires Admin SDK credentials):

```cmd
python scripts/seed_nz_clubs.py
python scripts/seed_nz_clubs.py --dry-run
```

Seeds Botany, Howick, Pakuranga, and Shoreditch (London) demo clubs with locations, timezones, club codes, and upcoming meetings.

```cmd
python scripts/backfill_club_geo.py
```

Backfills `club_lat`, `club_lng`, and `club_timezone` for existing clubs missing geo data.

**CORS:** Allowed origins are in `app.py` (localhost:3000, toastmastersdaily.com, www). If the site is served from another origin (e.g. Firebase `*.web.app`), add it to `CORSMiddleware` `allow_origins`.
