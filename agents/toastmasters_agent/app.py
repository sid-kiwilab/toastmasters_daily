from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
from langgraph.graph import StateGraph, END
from langchain_openai import ChatOpenAI
from langchain_core.messages import HumanMessage, SystemMessage, AIMessage
from typing import TypedDict, Annotated, Sequence, Any
from langgraph.graph.message import add_messages
import os
import json
import logging

# Load env.yaml into os.environ if present (local Docker mount; Cloud Run uses --env-vars-file)
for path in ("env.yaml", "/app/env.yaml"):
    if os.path.isfile(path):
        try:
            import yaml
            with open(path) as f:
                for k, v in (yaml.safe_load(f) or {}).items():
                    if v is not None and os.environ.get(k) in (None, ""):
                        os.environ[k] = str(v)
        except Exception:
            pass
        break

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("toastmasters_agent")

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:8080"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

openai_api_key = os.getenv("OPENAI_API_KEY", "").strip()
llm = ChatOpenAI(
    model="gpt-4o",
    temperature=0.3,
    max_tokens=1000,
    api_key=openai_api_key or None,
)

SYSTEM_PROMPT = """You are a helpful assistant for the Toastmasters Daily app. Answer concisely and be friendly."""


class AgentState(TypedDict):
    messages: Annotated[Sequence[Any], add_messages]


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
agent = workflow.compile()


async def stream_agent_response(messages: list):
    try:
        async for event in agent.astream({"messages": messages}, stream_mode="messages"):
            for msg in event:
                if isinstance(msg, AIMessage) and msg.content:
                    yield f"data: {json.dumps({'content': msg.content})}\n\n"
        yield "data: [DONE]\n\n"
    except Exception as e:
        yield f"data: {json.dumps({'error': str(e)})}\n\n"
        yield "data: [DONE]\n\n"


@app.post("/chat")
async def chat(request: Request):
    try:
        body = await request.json()
        msg = body.get("message", "")
        logger.info("Chat request: %r", msg[:80] + "..." if len(msg) > 80 else msg)
        history = body.get("history", [])
        stream = body.get("stream", False)

        messages = []
        for h in history:
            if h.get("sender") == "user":
                messages.append(HumanMessage(content=h.get("text", "")))
            elif h.get("sender") == "bot":
                messages.append(AIMessage(content=h.get("text", "")))
        messages.append(HumanMessage(content=msg))

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
        return JSONResponse(status_code=500, content={"error": str(e)})


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
