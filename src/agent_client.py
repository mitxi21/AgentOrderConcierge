"""
Thin client for Salesforce's Agent API.

Docs: https://developer.salesforce.com/docs/ai/agentforce/guide/agent-api.html

Requires an External Client App configured for the Client Credentials flow
(see Salesforce docs: "Get Started with the Agent API" for the exact OAuth
scopes and settings needed on the ECA).
"""
import os
import time
import uuid
import requests


class AgentforceClient:
    def __init__(self, my_domain_url, client_id, client_secret,
                 agent_id, api_base="https://api.salesforce.com"):
        self.my_domain_url = my_domain_url.rstrip("/")
        self.client_id = client_id
        self.client_secret = client_secret
        self.agent_id = agent_id
        self.api_base = api_base.rstrip("/")
        self._access_token = None
        self.session_id = None
        self._sequence_id = 0

    # ---- auth ----
    def _get_token(self):
        if self._access_token:
            return self._access_token
        resp = requests.post(
            f"{self.my_domain_url}/services/oauth2/token",
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            data={
                "grant_type": "client_credentials",
                "client_id": self.client_id,
                "client_secret": self.client_secret,
            },
            timeout=30,
        )
        resp.raise_for_status()
        self._access_token = resp.json()["access_token"]
        return self._access_token

    def _headers(self, accept="application/json"):
        return {
            "Content-Type": "application/json",
            "Accept": accept,
            "Authorization": f"Bearer {self._get_token()}",
        }

    # ---- session lifecycle ----
    def start_session(self, bypass_user=True):
        """Starts a new session and returns the list of initial agent messages."""
        url = f"{self.api_base}/einstein/ai-agent/v1/agents/{self.agent_id}/sessions"
        payload = {
            "externalSessionKey": str(uuid.uuid4()),
            "instanceConfig": {"endpoint": self.my_domain_url},
            "streamingCapabilities": {"chunkTypes": ["Text"]},
            "bypassUser": bypass_user,
        }
        resp = requests.post(url, headers=self._headers(), json=payload, timeout=60)
        resp.raise_for_status()
        data = resp.json()
        self.session_id = data["sessionId"]
        self._sequence_id = 0
        return data.get("messages", [])

    def send_message(self, text):
        """Sends one user turn synchronously and returns the list of response messages."""
        if not self.session_id:
            raise RuntimeError("Call start_session() first.")
        self._sequence_id += 1
        url = f"{self.api_base}/einstein/ai-agent/v1/sessions/{self.session_id}/messages"
        payload = {
            "message": {
                "sequenceId": self._sequence_id,
                "type": "Text",
                "text": text,
            }
        }
        resp = requests.post(url, headers=self._headers(), json=payload, timeout=60)
        resp.raise_for_status()
        return resp.json().get("messages", [])

    def end_session(self, reason="UserRequest"):
        if not self.session_id:
            return
        url = f"{self.api_base}/einstein/ai-agent/v1/sessions/{self.session_id}"
        requests.delete(
            url,
            headers={**self._headers(), "x-session-end-reason": reason},
            timeout=30,
        )
        self.session_id = None


def client_from_env():
    """Convenience constructor reading config from environment variables."""
    return AgentforceClient(
        my_domain_url=os.environ["SF_MY_DOMAIN_URL"],
        client_id=os.environ["SF_CLIENT_ID"],
        client_secret=os.environ["SF_CLIENT_SECRET"],
        agent_id=os.environ["SF_AGENT_ID"],
        api_base=os.environ.get("SF_API_BASE", "https://api.salesforce.com"),
    )
