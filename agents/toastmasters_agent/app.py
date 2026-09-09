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


def _load_action(name: str):
    path = os.path.join(_ACTIONS_DIR, f"{name}.py")
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.run

web_search_run = _load_action("web_search")
join_meeting_run = _load_action("join_meeting")
find_nearby_clubs_run = _load_action("find_nearby_clubs")

_request_location: contextvars.ContextVar[str | None] = contextvars.ContextVar(
    "request_location", default=None
)
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

SYSTEM_PROMPT = """You are Toasty, the assistant for Toastmasters Daily. You are warm, friendly, and happy to chat.

IMPORTANT: Treat the LATEST user message as the primary intent. Do not get confused by earlier messages—respond to what they just said.

You have exactly three action types; use them only when the latest message clearly fits. Otherwise, reply with normal chat (no tools).

1) NEARBY CLUBS — When the user asks for clubs "near me", "nearest", "closest", "clubs near [place]", or wants to join their nearest/closest club, call find_nearby_clubs. Pass their location from context, or a place name they typed. Do NOT use web_search for finding nearby clubs. Do NOT use find_club for geographic search (never pass "nearest" or a suburb to find_club).

2) JOIN A NAMED CLUB — When the user wants to JOIN a specific club by name (e.g. "join Botany Toastmasters", "get link for Pakuranga"), call find_club with that club name. If they only ask "what is X club?" without join intent, you may use find_club to show details or answer in chat.

3) GENERAL TOASTMASTERS INFO — Use web_search only for general Toastmasters facts, Pathways, official TI info, or things not stored on Toastmasters Daily. Never use web_search to find clubs near the user.

LOCATION: If the user's location is provided below, use it for find_nearby_clubs. Do not ask for location when it is already in context.

RESPONSE FORMAT: When presenting clubs from find_club or find_nearby_clubs, always show the tool output details (name, location, about, next meeting, links). Then briefly explain that "Club page (guest join)" is a temporary guest visit on Toastmasters Daily, not official TI membership. Include the URLs from the tool output so the user can click through.

You cannot perform any other actions (no creating meetings, QR codes, voting, or opening agendas). You can describe what the site can do so users know where to go.

What Toastmasters Daily lets users do on the site: QR codes for meetings, manage meetings online, vote in meetings, view agendas. Direct users to the site for those. You can give speech tips and Toastmasters advice. Keep answers concise. If off-topic, stay friendly and briefly engage, then offer to help with meetings or speaking when they'd like."""


def _system_prompt_with_datetime(location: str | None = None) -> str:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    out = f"Current date and time: {now}.\n\n{SYSTEM_PROMPT}"
    if location and location.strip():
        out += f"\n\nThe user's location is: {location.strip()}. Use find_nearby_clubs with this location when they ask for clubs 'near me', 'nearest', or 'closest'—do not ask them for it."
    else:
        out += "\n\nThe user's location was not provided. If they ask for clubs 'near me' or 'closest', reply in chat and suggest they share location or type their city—or call find_nearby_clubs with a city they mention."
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
    """Find Toastmasters Daily clubs closest to a location. Use for 'near me', 'nearest', 'closest', or 'clubs near [place]'. Pass the user's location from context, or a city/suburb they typed. Returns club details, distance, next meeting, and guest join URLs."""
    loc = (place or "").strip() or (_request_location.get() or "")
    coords = _request_coords.get()
    lat, lng = (coords if coords else (None, None))
    return find_nearby_clubs_run(loc, lat=lat, lng=lng)


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
    loc_token = _request_location.set(str(location).strip() if location else None)
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
        _request_location.reset(loc_token)
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

        loc_token = _request_location.set(location)
        coord_token = _request_coords.set(coords)
        state = {"messages": messages}
        if location:
            state["location"] = location
        try:
            result = agent.invoke(state)
        finally:
            _request_location.reset(loc_token)
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
