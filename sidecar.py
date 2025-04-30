"""Logic that runs in the sidecar container.
Here we wait until the graph is accepting connections
and then run the one-time (typically building indexes)
and every (typically warmup) scripts.
"""
from datetime import datetime
import os
from pathlib import Path
import random
import time

from neo4j import GraphDatabase
from neo4j.exceptions import ServiceUnavailable

_ME = "sidecar.py"

_NEO4J_AUTH: list[str] = os.environ["NEO4J_AUTH"].split("/")
_URI: str = "neo4j://localhost:7687"
_AUTH = (_NEO4J_AUTH[0], _NEO4J_AUTH[1])

_CYPHER_ROOT: str = os.environ["CYPHER_ROOT"]

_ONCE_SCRIPT: str = ""
_PATH: str = f"{_CYPHER_ROOT}/cypher-script/cypher-script.once"
if os.path.isfile(_PATH):
    with open(_PATH, "rt", encoding="utf-8") as file:
        _ONCE_SCRIPT = file.read().strip()
_ONCE_EXECUTED: str = f"{_PATH}.executed"

_ALWAYS_SCRIPT: str = ""
_PATH: str = f"{_CYPHER_ROOT}/cypher-script/cypher-script.always"
if os.path.isfile(_PATH):
    with open(_PATH, "rt", encoding="utf-8") as file:
        _ALWAYS_SCRIPT = file.read().strip()

# Connect if there's any cypher script to run...
if _ALWAYS_SCRIPT or _ONCE_SCRIPT:

    print(f"({_ME}) {datetime.now()} Waiting for a connection to '{_URI}' AUTH={_AUTH}...")
    _CONNECTED: bool = False
    while not _CONNECTED:
        try:
            with GraphDatabase.driver(_URI, auth=_AUTH) as driver:
                driver.verify_connectivity()
            _CONNECTED = True
        except ServiceUnavailable:
            # No service, wait for a few minutes...
            time.sleep(random.randint(1, 10) * 60)
    assert _CONNECTED

print(f"({_ME}) {datetime.now()} Connected")

# Run any 'once' script (if the 'executed' file does not exist)...
if _ONCE_SCRIPT and not os.path.isfile(_ONCE_EXECUTED):
    print(f"({_ME}) {datetime.now()} Running ONCE script...")
    with GraphDatabase.driver(_URI, auth=_AUTH) as driver:
        _, _, _ = driver.execute_query(_ONCE_SCRIPT)
    print(f"({_ME}) {datetime.now()} Done - ONCE")
    # Create the 'executed' script to avoid doing this again
    Path(_ONCE_EXECUTED).touch()

# Run any 'always' script...
if _ALWAYS_SCRIPT:
    print(f"({_ME}) {datetime.now()} Running ALWAYS script...")
    with GraphDatabase.driver(_URI, auth=_AUTH) as driver:
        _, _, _ = driver.execute_query(_ALWAYS_SCRIPT)
    print(f"({_ME}) {datetime.now()} Done - ALWAYS")

# Stay here forever...
while True:
    time.sleep(25)
