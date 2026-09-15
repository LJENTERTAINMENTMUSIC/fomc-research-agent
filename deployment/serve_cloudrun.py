# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""HTTP API server for FOMC Research Agent.

Replaces the Vertex AI Agent Engine deployment with a standard
FastAPI server that can run on Cloud Run, Railway, Render, or any VPS.

Usage:
    python deployment/serve_cloudrun.py
    # Or via uvicorn:
    uvicorn deployment.serve_cloudrun:app --host 0.0.0.0 --port 8080
"""

import asyncio
import logging
import os
import uuid
from contextlib import asynccontextmanager

import uvicorn
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from google.adk.runners import Runner
from google.adk.sessions import InMemorySessionService
from google.genai import types

# Load environment variables
load_dotenv()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Global references
runner = None
session_service = None
APP_NAME = "fomc_research"


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize the ADK runner on startup."""
    global runner, session_service

    # Import agent here to ensure env vars are loaded first
    from fomc_research.agent import root_agent

    session_service = InMemorySessionService()
    runner = Runner(
        agent=root_agent,
        app_name=APP_NAME,
        session_service=session_service,
    )
    logger.info("FOMC Research Agent initialized successfully.")
    yield
    logger.info("FOMC Research Agent shutting down.")


app = FastAPI(
    title="FOMC Research Agent API",
    description=(
        "HTTP API for the FOMC Research Agent — analyzes Federal Open Market "
        "Committee meetings. Replaces Vertex AI Agent Engine deployment."
    ),
    version="0.1.0",
    lifespan=lifespan,
)

# CORS for frontend access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# --- Request/Response Models ---


class AgentRequest(BaseModel):
    """Request body for agent interaction."""

    message: str = Field(..., description="User message to send to the agent")
    user_id: str = Field(
        default_factory=lambda: str(uuid.uuid4()),
        description="User identifier",
    )
    session_id: str | None = Field(
        default=None,
        description="Existing session ID (omit to create new)",
    )


class AgentResponse(BaseModel):
    """Response from the agent."""

    session_id: str
    user_id: str
    response: str
    agent_name: str | None = None


class SessionInfo(BaseModel):
    """Session information."""

    session_id: str
    user_id: str
    app_name: str


class HealthResponse(BaseModel):
    """Health check response."""

    status: str
    agent: str
    version: str


# --- API Endpoints ---


@app.get("/api/health", response_model=HealthResponse)
def health_check():
    """Health check endpoint."""
    return HealthResponse(
        status="ok",
        agent="fomc-research",
        version="0.1.0",
    )


@app.post("/api/sessions", response_model=SessionInfo)
async def create_session(user_id: str = None):
    """Create a new agent session."""
    if not user_id:
        user_id = str(uuid.uuid4())

    session = await session_service.create_session(
        app_name=APP_NAME,
        user_id=user_id,
    )
    return SessionInfo(
        session_id=session.id,
        user_id=user_id,
        app_name=APP_NAME,
    )


@app.post("/api/agent/run", response_model=AgentResponse)
async def run_agent(request: AgentRequest):
    """Send a message to the FOMC Research Agent and get a response.

    The agent uses a multi-agent architecture:
    - root_agent: Coordinates the workflow
    - research_agent: Fetches FOMC data from the web
    - analysis_agent: Generates the final analysis report

    Typical workflow:
    1. Send "Hello. What can you do for me?"
    2. Agent asks for a meeting date
    3. Send "2025-01-29" (or any FOMC meeting date)
    4. Agent generates a detailed analysis report
    """
    user_id = request.user_id
    session_id = request.session_id

    # Create session if none provided
    if not session_id:
        session = await session_service.create_session(
            app_name=APP_NAME,
            user_id=user_id,
        )
        session_id = session.id

    # Build the user message
    user_message = types.Content(
        role="user",
        parts=[types.Part.from_text(text=request.message)],
    )

    # Run the agent and collect response
    response_parts = []
    final_agent_name = None

    try:
        async for event in runner.run_async(
            user_id=user_id,
            session_id=session_id,
            new_message=user_message,
        ):
            if event.is_final_response():
                if event.content and event.content.parts:
                    for part in event.content.parts:
                        if part.text:
                            response_parts.append(part.text)
                if hasattr(event, "author"):
                    final_agent_name = event.author
    except Exception as e:
        logger.error(f"Agent execution error: {e}")
        raise HTTPException(status_code=500, detail=f"Agent error: {str(e)}")

    return AgentResponse(
        session_id=session_id,
        user_id=user_id,
        response=(
            "\n".join(response_parts)
            if response_parts
            else "Agent did not produce a response. Try asking it to continue."
        ),
        agent_name=final_agent_name,
    )


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    logger.info(f"Starting FOMC Research Agent API on port {port}")
    uvicorn.run(
        "deployment.serve_cloudrun:app",
        host="0.0.0.0",
        port=port,
        reload=False,
    )
