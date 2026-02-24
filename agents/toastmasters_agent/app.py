import os
import json
import logging

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
from langchain_openai import ChatOpenAI
from langchain_core.messages import HumanMessage, SystemMessage, AIMessage
from typing import TypedDict, Annotated, Sequence, Any
from langgraph.graph.message import add_messages

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "https://toastmastersdaily.com"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

SYSTEM_PROMPT = """You are Toasty, the assistant for Toastmasters Daily. You are warm, friendly, and happy to chat. You only speak about the Toastmasters brand and this app when it's relevant, but you're not cold or robotic—you can briefly acknowledge what someone said (e.g. "That's cool!" or "Nice!") before gently offering to help with the site or Toastmasters when they're ready.

You cannot perform any actions (you cannot create meetings, show QR codes, vote, or open agendas). You can only describe what the site can do so users know where to go and what to try.

What Toastmasters Daily lets users do on the site:
- QR codes for meetings so members can join quickly
- Manage meetings online (create and run meetings digitally)
- Vote in meetings (e.g. best speaker, table topics winner)
- View agendas
- Makes the Toastmasters meeting experience digital and easier

Direct users to use the site for those things. You can also give speech tips and general Toastmasters advice. Keep answers concise. If the topic is clearly off Toastmasters and the app, stay friendly and briefly engage, then offer to help with meetings or speaking when they'd like."""


class AgentState(TypedDict):
    messages: Annotated[Sequence[Any], add_messages]


_agent = None


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

    def agent_node(state: AgentState) -> AgentState:
        messages = state["messages"]
        if not messages or not isinstance(messages[0], SystemMessage):
            messages = [SystemMessage(content=SYSTEM_PROMPT)] + list(messages)
        response = llm.invoke(messages)
        return {"messages": [response]}

    workflow = StateGraph(AgentState)
    workflow.add_node("agent", agent_node)
    workflow.set_entry_point("agent")
    workflow.add_edge("agent", END)
    _agent = workflow.compile()
    return _agent


async def stream_agent_response(messages: list):
    agent = _get_agent()
    if not agent:
        yield f"data: {json.dumps({'error': 'OPENAI_API_KEY not configured'})}\n\n"
        yield "data: [DONE]\n\n"
        return
    try:
        async for event in agent.astream({"messages": messages}, stream_mode="messages"):
            for msg in event:
                if isinstance(msg, AIMessage) and msg.content:
                    yield f"data: {json.dumps({'content': msg.content})}\n\n"
        yield "data: [DONE]\n\n"
    except Exception as e:
        logger.exception("Chat stream error")
        yield f"data: {json.dumps({'error': str(e)})}\n\n"
        yield "data: [DONE]\n\n"


@app.post("/chat")
async def chat(request: Request):
    try:
        body = await request.json()
        msg = (body.get("message") or "").strip()
        logger.info("Chat request: %r", msg[:80] + "..." if len(msg) > 80 else msg)
        history = body.get("history") or []
        stream = body.get("stream", False)

        messages = []
        for h in history:
            if h.get("sender") == "user":
                messages.append(HumanMessage(content=h.get("text", "")))
            elif h.get("sender") == "bot":
                messages.append(AIMessage(content=h.get("text", "")))
        messages.append(HumanMessage(content=msg))

        agent = _get_agent()
        if not agent:
            return JSONResponse(status_code=503, content={"error": "OPENAI_API_KEY not configured"})

        if stream:
            return StreamingResponse(
                stream_agent_response(messages),
                media_type="text/event-stream",
                headers={"Cache-Control": "no-cache", "Connection": "keep-alive", "X-Accel-Buffering": "no"},
            )

        result = agent.invoke({"messages": messages})
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
