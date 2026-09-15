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

"""Initialization functions for FOMC Research Agent.

Supports two backends:
  - Vertex AI (GOOGLE_GENAI_USE_VERTEXAI=1) — requires GCP credentials
  - ML Dev / API Key (GOOGLE_GENAI_USE_VERTEXAI=0) — only needs GOOGLE_API_KEY
"""

import logging
import os

from dotenv import load_dotenv

# Load .env file if present
load_dotenv()

# Try GCP auth — gracefully handle non-GCP environments
try:
    import google.auth
    _, project_id = google.auth.default()
    if project_id:
        os.environ.setdefault("GOOGLE_CLOUD_PROJECT", project_id)
except Exception:
    # Running outside GCP (Railway, Render, VPS, etc.)
    # GOOGLE_CLOUD_PROJECT must be set manually via .env or env vars
    pass

os.environ.setdefault("GOOGLE_CLOUD_LOCATION", "global")

# Default to API key mode if not specified (easier for non-GCP platforms)
# Set to "1" or "True" to use Vertex AI backend instead
os.environ.setdefault("GOOGLE_GENAI_USE_VERTEXAI", "False")

loglevel = os.getenv("GOOGLE_GENAI_FOMC_AGENT_LOG_LEVEL", "INFO")
numeric_level = getattr(logging, loglevel.upper(), None)
if not isinstance(numeric_level, int):
    raise ValueError(f"Invalid log level: {loglevel}")
logger = logging.getLogger(__package__)
logger.setLevel(numeric_level)

MODEL = os.getenv("GOOGLE_GENAI_MODEL")
if not MODEL:
    MODEL = "gemini-2.5-flash"

# MODEL needs to be defined before this import
from . import agent  # noqa: E402

