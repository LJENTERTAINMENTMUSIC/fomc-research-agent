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

"""Standalone CLI runner for FOMC Research Agent.

Runs the agent without Vertex AI Agent Engine — just a simple
command-line interface for local development and VPS usage.

Usage:
    python deployment/serve_cli.py
"""

import asyncio
import logging
import sys

from dotenv import load_dotenv

from google.adk.runners import Runner
from google.adk.sessions import InMemorySessionService
from google.genai import types

# Load environment variables
load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(name)s] %(levelname)s: %(message)s",
)
logger = logging.getLogger(__name__)

APP_NAME = "fomc_research"


async def main():
    """Run the FOMC Research Agent interactively."""
    # Import agent after env vars are loaded
    from fomc_research.agent import root_agent

    session_service = InMemorySessionService()
    runner = Runner(
        agent=root_agent,
        app_name=APP_NAME,
        session_service=session_service,
    )

    # Create a session
    session = await session_service.create_session(
        app_name=APP_NAME,
        user_id="cli-user",
    )

    print("\n" + "=" * 60)
    print("  FOMC Research Agent — Standalone CLI")
    print("  Type 'exit' or 'quit' to stop.")
    print("")
    print("  Quick start:")
    print("    1. Say: Hello. What can you do for me?")
    print("    2. Give a date: 2025-01-29")
    print("    3. Wait for the analysis report")
    print("=" * 60 + "\n")

    while True:
        try:
            user_input = input("You: ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nGoodbye!")
            break

        if not user_input:
            continue
        if user_input.lower() in ("exit", "quit"):
            print("Goodbye!")
            break

        # Build user message
        user_message = types.Content(
            role="user",
            parts=[types.Part.from_text(text=user_input)],
        )

        # Run agent
        try:
            async for event in runner.run_async(
                user_id="cli-user",
                session_id=session.id,
                new_message=user_message,
            ):
                if event.is_final_response():
                    if event.content and event.content.parts:
                        for part in event.content.parts:
                            if part.text:
                                agent_name = getattr(event, "author", "Agent")
                                print(f"\n[{agent_name}]: {part.text}\n")
        except Exception as e:
            logger.error(f"Agent error: {e}")
            print(f"\n[ERROR]: {e}\n")


if __name__ == "__main__":
    asyncio.run(main())
