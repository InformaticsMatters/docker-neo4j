#!/bin/bash

# A script for use as a Docker/Kubernetes 'readiness probe'.
# Used to determine whether the database is 'ready'.
#
# We assume the following environment variables exist: -
#
#   CYPHER_ROOT
#   NEO4J_dbms_directories_logs
#
# This code inspects the debug log looking for a line that
# contains 'Database graph.db is ready'. The file is expected
# to be called $NEO4J_dbms_directories_logs/debug.log
#
# If the line is found then we check for 'once' and 'always' script
# execution by expecting a '.executed' file in the cypher-script
# directory as each one completes. The 'once' runs on the first launch
# of the Pod and the 'always' for every Pod start.

CYPHER_PATH="$CYPHER_ROOT/cypher-script"

# Not started if there's no debug file.
# It's removed by the loader each time the Pod restarts.
DEBUG_FILE="$NEO4J_dbms_directories_logs/debug.log"
if [ ! -f "$DEBUG_FILE" ]; then
  echo "Not ready - no debug file ($DEBUG_FILE)"
  exit 1
fi

# Does a 'ready' line exist?
READY=$(grep -c "Database.*graph[.]db.* is ready." < "$DEBUG_FILE")
if [ "$READY" -eq "0" ]; then
  echo "Not ready - according to debug file ($DEBUG_FILE)"
  exit 1
fi

# If there's no 'once.executed' we're not 'live'
ONCE_EXECUTED_FILE="$CYPHER_PATH/once.executed"
if [ ! -f "$ONCE_EXECUTED_FILE" ]; then
  echo "Not ready - no $ONCE_EXECUTED_FILE"
  exit 1
fi

# If there's no 'always.executed' we're not 'live'
ALWAYS_EXECUTED_FILE="$CYPHER_PATH/always.executed"
if [ ! -f "$ALWAYS_EXECUTED_FILE" ]; then
  echo "Not ready - no $ALWAYS_EXECUTED_FILE"
  exit 1
fi

# Graph Database is 'Ready' if we get here...
# Nothing to do - return value of zero is all that's needed.
echo "Ready"
