import os
import json
import logging
import importlib.util
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
from typing import TypedDict, Annotated, Sequence, Any, NotRequired
from langgraph.graph.message import add_messages

# Load actions from files (no __init__.py)
def _load_action(name: str):
    path = os.path.join(os.path.dirname(__file__), "actions", f"{name}.py")
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.run

web_search_run = _load_action("web_search")
join_meeting_run = _load_action("join_meeting")

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

1) JOIN MEETING — Only when the user's message indicates they want to JOIN or get a join link. Look for intent like: "join", "join link", "get the link", "how do I join", "join the meeting", "join [club name]", "link to join", etc. (fuzzy match is fine). If they only ask "what is X club?" or "tell me about Botany Toastmasters" without any join intent, do NOT use find_club—answer in chat or use web_search if you need info. Only call find_club when join (or equivalent) is clearly in the request.

2) SEARCH CLUB / TOASTMASTERS INFO — Use web_search for: general Toastmasters facts, club info, recent events, dates, official info, or anything you want to verify. Do not use find_club for this.

3) LIST CLUBS NEAR USER — When the user asks for clubs "near me", "nearest", "closest", or similar, use web_search with the location already provided in this conversation (see below). Only do this when you have been given the user's location—do not ask the user for their location if it is already provided.

LOCATION: If the user's location is provided below, use it. Do not ask the user for their location when it is already in context. For "near me" / "nearest" requests, use that location in your web search.

You cannot perform any other actions (no creating meetings, QR codes, voting, or opening agendas). You can describe what the site can do so users know where to go.

What Toastmasters Daily lets users do on the site: QR codes for meetings, manage meetings online, vote in meetings, view agendas. Direct users to the site for those. You can give speech tips and Toastmasters advice. Keep answers concise. If off-topic, stay friendly and briefly engage, then offer to help with meetings or speaking when they'd like."""


def _system_prompt_with_datetime(location: str | None = None) -> str:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    out = f"Current date and time: {now}.\n\n{SYSTEM_PROMPT}"
    if location and location.strip():
        out += f"\n\nThe user's location is: {location.strip()}. Use this when they ask for clubs/meetings 'near me', 'nearest', or 'closest'—search with this location; do not ask them for it."
    else:
        out += "\n\nThe user's location was not provided. If they ask for clubs 'near me' or 'closest', reply in chat and suggest they share location or type their city—do not call find_club for that."
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
    """Only use when the user clearly wants to JOIN a meeting or get a join link (e.g. 'join Botany Toastmasters', 'get link for X'). Do NOT use for general club info or 'what is X club'. Pass the club name (or part of it). Returns club name(s) and join URL(s) or 'No matching clubs.'"""
    return join_meeting_run(query)


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
    tools = [web_search, find_club]
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


async def stream_agent_response(messages: list, location: str | None = None):
    agent = _get_agent()
    if not agent:
        yield f"data: {json.dumps({'error': 'OPENAI_API_KEY not configured'})}\n\n"
        yield "data: [DONE]\n\n"
        return
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

        agent = _get_agent()
        if not agent:
            return JSONResponse(status_code=503, content={"error": "OPENAI_API_KEY not configured"})

        if stream:
            return StreamingResponse(
                stream_agent_response(messages, location=location),
                media_type="text/event-stream",
                headers={"Cache-Control": "no-cache", "Connection": "keep-alive", "X-Accel-Buffering": "no"},
            )

        state = {"messages": messages}
        if location:
            state["location"] = location
        result = agent.invoke(state)
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
