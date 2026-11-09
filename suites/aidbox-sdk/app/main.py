"""Stub app: the SDK's pytest plugin always starts one, and this suite has no operations."""

from aidbox_python_sdk.main import create_app
from aidbox_python_sdk.sdk import SDK
from aidbox_python_sdk.settings import Settings
from aiohttp import web


def application() -> web.Application:
    return create_app(SDK(Settings()))
