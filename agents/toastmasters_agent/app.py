import os
import sys
import json
import logging
import importlib.util
import contextvars
from datetime import datetime, timezone

# Load env.yaml from next to this file (YAML map: KEY: "value" — same as kiwilab_functions)
_env_path = os.path.join(os.path.dirname(__file__), "env.yaml")
if os.path.isfile(_env_path):
    import yaml
    with open(_env_path) as f:
        data = yaml.safe_load(f)
    if isinstance(data, dict):
        for k, v in data.items():
            if v is not None and str(v).strip():
                os.environ.setdefault(k, str(v).strip())

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("toastmasters_agent")

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
from langgraph.graph import StateGraph, END
from langgraph.prebuilt import ToolNode
from langchain_openai import ChatOpenAI
from langchain_core.messages import HumanMessage, SystemMessage, AIMessage
from langchain_core.tools import tool
from typing import TypedDict, Annotated, Sequence, Any

try:
    from typing import NotRequired
except ImportError:
    from typing_extensions import NotRequired
from langgraph.graph.message import add_messages

# Load actions from files (no __init__.py)
_ACTIONS_DIR = os.path.join(os.path.dirname(__file__), "actions")
if _ACTIONS_DIR not in sys.path:
    sys.path.insert(0, _ACTIONS_DIR)


def _load_action_module(name: str):
    path = os.path.join(_ACTIONS_DIR, f"{name}.py")
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

_web_search_mod = _load_action_module("web_search")
_join_mod = _load_action_module("join_meeting")
_nearby_mod = _load_action_module("find_nearby_clubs")

web_search_run = _web_search_mod.run
join_meeting_run = _join_mod.run
find_nearby_clubs_run = _nearby_mod.run

_request_coords: contextvars.ContextVar[tuple[float, float] | None] = contextvars.ContextVar(
    "request_coords", default=None
)

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "https://toastmastersdaily.com", "https://www.toastmastersdaily.com"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Input caps to prevent token abuse. Enforced server-side.
MAX_MESSAGE_CHARS = 1000
MAX_TOTAL_INPUT_CHARS = 6000

SYSTEM_PROMPT = """You are Toasty, the assistant for Toastmasters Daily. Warm, friendly, concise.

Respond to the LATEST user message. Use tools when needed:

- find_nearby_clubs(place): when the user wants clubs near a location. If they name a city or area, pass it as place (GPS is ignored). If they mean their current location ("near me"), pass an empty place. Returns signed-up clubs with guest join, or official web results if none nearby.
- find_club(name): join or look up a specific club by name on Toastmasters Daily.
- web_search(query): general Toastmasters info (Pathways, TI facts).

Keep answers short. Echo club tool output without inventing links."""


def _system_prompt_with_datetime(location: str | None = None) -> str:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    out = f"Current date and time: {now}.\n\n{SYSTEM_PROMPT}"
    if location and location.strip():
        out += (
            f"\n\nUser GPS area: {location.strip()}. "
            "Only use GPS (empty place) when they mean near me — never pass this as place if they named another city."
        )
    return out


class AgentState(TypedDict):
    messages: Annotated[Sequence[Any], add_messages]
    location: NotRequired[str]


_agent = None


@tool
def web_search(query: str) -> str:
    """Search the web for current information. Use for: recent events, facts, dates, official info, or anything to verify. Returns a summarized answer from search results."""
    return web_search_run(query)


@tool
def find_club(query: str) -> str:
    """Use when the user wants to JOIN a specific club by name (e.g. 'join Botany Toastmasters'). Pass the club name (or part of it). Do NOT use for 'nearest' or location-based search. Returns club details, next meeting, and guest join URLs."""
    return join_meeting_run(query)


@tool
def find_nearby_clubs(place: str = "") -> str:
    """Clubs near a location. Pass the city/area as place, or empty for GPS near me."""
    typed = (place or "").strip()
    if typed:
        return find_nearby_clubs_run(typed)
    coords = _request_coords.get()
    lat, lng = (coords if coords else (None, None))
    return find_nearby_clubs_run("", lat=lat, lng=lng)


def _get_agent():
    """Lazy-init LangGraph agent so the app boots even when OPENAI_API_KEY is missing."""
    global _agent
    if _agent is not None:
        return _agent
    key = os.getenv("OPENAI_API_KEY", "").strip()
    if not key:
        return None
    llm = ChatOpenAI(
        model="gpt-4o",
        temperature=0.3,
        max_tokens=1000,
        api_key=key,
    )
    tools = [web_search, find_club, find_nearby_clubs]
    llm_with_tools = llm.bind_tools(tools)

    def agent_node(state: AgentState) -> AgentState:
        messages = state["messages"]
        location = state.get("location") if isinstance(state.get("location"), str) else None
        if not messages or not isinstance(messages[0], SystemMessage):
            messages = [SystemMessage(content=_system_prompt_with_datetime(location=location))] + list(messages)
        response = llm_with_tools.invoke(messages)
        return {"messages": [response]}

    tool_node = ToolNode(tools)

    def should_continue(state: AgentState):
        last = state["messages"][-1]
        if hasattr(last, "tool_calls") and last.tool_calls:
            return "tools"
        return END

    workflow = StateGraph(AgentState)
    workflow.add_node("agent", agent_node)
    workflow.add_node("tools", tool_node)
    workflow.set_entry_point("agent")
    workflow.add_conditional_edges("agent", should_continue)
    workflow.add_edge("tools", "agent")
    _agent = workflow.compile()
    return _agent


def _parse_coords(body: dict) -> tuple[float, float] | None:
    try:
        lat = body.get("lat")
        lng = body.get("lng")
        if lat is None or lng is None:
            return None
        return (float(lat), float(lng))
    except (TypeError, ValueError):
        return None


async def stream_agent_response(
    messages: list,
    location: str | None = None,
    coords: tuple[float, float] | None = None,
):
    agent = _get_agent()
    if not agent:
        yield f"data: {json.dumps({'error': 'OPENAI_API_KEY not configured'})}\n\n"
        yield "data: [DONE]\n\n"
        return
    coord_token = _request_coords.set(coords)
    state = {"messages": messages}
    if location and str(location).strip():
        state["location"] = str(location).strip()
    try:
        async for event in agent.astream(state, stream_mode="messages"):
            for msg in event:
                if isinstance(msg, AIMessage) and msg.content:
                    yield f"data: {json.dumps({'content': msg.content})}\n\n"
        yield "data: [DONE]\n\n"
    except Exception as e:
        logger.exception("Chat stream error")
        yield f"data: {json.dumps({'error': str(e)})}\n\n"
        yield "data: [DONE]\n\n"
    finally:
        _request_coords.reset(coord_token)


def _trim_history_to_char_limit(history: list, current_message: str, max_total: int) -> list:
    """Keep only the most recent history so total text length <= max_total."""
    current_len = len(current_message)
    budget = max(0, max_total - current_len)
    if budget <= 0:
        return []
    trimmed = []
    total = 0
    for h in reversed(history):
        text = (h.get("text") or "").strip()
        if not text:
            continue
        if total + len(text) > budget:
            break
        trimmed.append((h.get("sender"), text))
        total += len(text)
    trimmed.reverse()
    return trimmed


@app.post("/chat")
async def chat(request: Request):
    try:
        body = await request.json()
        msg = (body.get("message") or "").strip()
        if len(msg) > MAX_MESSAGE_CHARS:
            return JSONResponse(
                status_code=400,
                content={"error": f"Message too long. Maximum {MAX_MESSAGE_CHARS} characters per message."},
            )
        logger.info("Chat request: %r", msg[:80] + "..." if len(msg) > 80 else msg)
        history = body.get("history") or []
        stream = body.get("stream", False)

        history_trimmed = _trim_history_to_char_limit(history, msg, MAX_TOTAL_INPUT_CHARS)

        messages = []
        for sender, text in history_trimmed:
            if sender == "user":
                messages.append(HumanMessage(content=text))
            elif sender == "bot":
                messages.append(AIMessage(content=text))
        messages.append(HumanMessage(content=msg))

        location = (body.get("location") or "").strip() or None
        coords = _parse_coords(body)

        agent = _get_agent()
        if not agent:
            return JSONResponse(status_code=503, content={"error": "OPENAI_API_KEY not configured"})

        if stream:
            return StreamingResponse(
                stream_agent_response(messages, location=location, coords=coords),
                media_type="text/event-stream",
                headers={"Cache-Control": "no-cache", "Connection": "keep-alive", "X-Accel-Buffering": "no"},
            )

        coord_token = _request_coords.set(coords)
        state = {"messages": messages}
        if location:
            state["location"] = location
        try:
            result = agent.invoke(state)
        finally:
            _request_coords.reset(coord_token)
        msgs = result.get("messages", [])
        for m in reversed(msgs):
            if isinstance(m, AIMessage) and m.content:
                return {"response": m.content}
        return {"response": "No response."}
    except Exception as e:
        logger.exception("Chat error")
        return JSONResponse(status_code=500, content={"error": str(e)})


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
