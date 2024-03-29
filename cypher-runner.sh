#!/usr/bin/env bash

# Order of execution...
#
# 1. We run the ONCE_SCRIPT on first execution (if present)
# 2. We always run the ALWAYS_SCRIPT (if present)
#
# Expects the following environment variables: -
#
#   ACTION_SLEEP_TIME           (default of 4 seconds)
#   CYPHER_ROOT
#   GRAPH_PASSWORD
#   NEO4J_dbms_directories_data (default '/data')
#   NEO4J_dbms_directories_logs (default '/logs')

ME=cypher-runner.sh

# The graph user password is required as an environment variable.
# The user is expected to be 'neo4j'.
if [ -z "$GRAPH_PASSWORD" ]
then
  echo "($ME) $(date) No GRAPH_PASSWORD. Can't run without this."
  exit 0
fi

# The 'once' and 'always' cypher scripts
CYPHER_PATH="$CYPHER_ROOT/cypher-script"
ONCE_SCRIPT="$CYPHER_PATH/cypher-script.once"
ALWAYS_SCRIPT="$CYPHER_PATH/cypher-script.always"

# Files created (touched) when the 'once' script is run and completed
# and when the 'always' script is run and complete. These files are created
# even if there are no associated scripts. The 'always' file
# is erased each time the container starts and re-created after the script has
# finished.
ONCE_EXECUTED_FILE="$CYPHER_PATH/once.executed"
ONCE_STARTED_FILE="$CYPHER_PATH/once.started"
ALWAYS_EXECUTED_FILE="$CYPHER_PATH/always.executed"
ALWAYS_STARTED_FILE="$CYPHER_PATH/always.started"

# Always remove the ALWAYS_EXECUTED_FILE.
# We re-create this when we've run the always script
# (which happens every time we start)
rm -f "$ALWAYS_EXECUTED_FILE" || true

ACTION_SLEEP_TIME=${ACTION_SLEEP_TIME:-4}
NEO4J_dbms_directories_data=${NEO4J_dbms_directories_data:-/data}
NEO4J_dbms_directories_logs=${NEO4J_dbms_directories_logs:-/logs}

echo "($ME) $(date) ALWAYS_EXECUTED_FILE=$ALWAYS_EXECUTED_FILE"
echo "($ME) $(date) ALWAYS_SCRIPT=$ALWAYS_SCRIPT"
echo "($ME) $(date) ACTION_SLEEP_TIME=$ACTION_SLEEP_TIME"
echo "($ME) $(date) CYPHER_ROOT=$CYPHER_ROOT"
echo "($ME) $(date) GRAPH_PASSWORD=$GRAPH_PASSWORD"
echo "($ME) $(date) NEO4J_dbms_directories_data=$NEO4J_dbms_directories_data"
echo "($ME) $(date) NEO4J_dbms_directories_logs=$NEO4J_dbms_directories_logs"
echo "($ME) $(date) ONCE_SCRIPT=$ONCE_SCRIPT"
echo "($ME) $(date) ONCE_EXECUTED_FILE=$ONCE_EXECUTED_FILE"

# The graph service has not started if there's no debug file.
DEBUG_FILE="$NEO4J_dbms_directories_logs/debug.log"
echo "($ME) $(date) Checking $DEBUG_FILE..."
until [ -f "$DEBUG_FILE" ]; do
  echo "($ME) $(date) Waiting for $DEBUG_FILE..."
  sleep "$ACTION_SLEEP_TIME"
done

# Wait until a line containing the expected 'ready' message or
# 'java.lang.RuntimeException' exists in the debug log...
echo "($ME) $(date) Checking ready line in $DEBUG_FILE..."
READY=$(grep -c "Database.*graph[.]db.* is ready." < "$DEBUG_FILE")
EXCEPTION=$(grep -c "java[.]lang[.]RuntimeException" < "$DEBUG_FILE")
while [[ "$READY" -eq "0" && "$EXCEPTION" -eq "0" ]]; do
  echo "($ME) $(date) Waiting for ready line in $DEBUG_FILE..."
  sleep "$ACTION_SLEEP_TIME"
  READY=$(grep -c "Database.*graph[.]db.* is ready." < "$DEBUG_FILE")
  EXCEPTION=$(grep -c "java[.]lang[.]RuntimeException" < "$DEBUG_FILE")
done

# Leave if we've seen an exception in the log.
# This is bad and indicates the data directory may be corrupt/incomplete.
if [[ "$EXCEPTION" -ne "0" ]]; then
  echo "($ME) $(date) ERROR: Found java.lang.RuntimeException in $DEBUG_FILE"
  echo "($ME) $(date) It's unsafe to continue the cypher runner. Leaving..."
  exit 0
fi

# Looks like initial DB startup is OK.
# Pause before running the first and always scripts.
echo "($ME) $(date) Post ready pause..."
sleep "$ACTION_SLEEP_TIME"

# Run the ONCE_SCRIPT
# (if the ONCE_EXECUTED_FILE is not present)...
if [[ ! -f "$ONCE_EXECUTED_FILE" && -f "$ONCE_SCRIPT" ]]; then
  echo "($ME) $(date) Trying $ONCE_SCRIPT..."
  echo "[SCRIPT BEGIN]"
  cat "$ONCE_SCRIPT"
  echo "[SCRIPT END]"
  touch "$ONCE_STARTED_FILE"
  until /var/lib/neo4j/bin/cypher-shell -u neo4j -p "$GRAPH_PASSWORD" < "$ONCE_SCRIPT"
  do
    echo "($ME) $(date) No joy with .once, waiting and trying again..."
    sleep "$ACTION_SLEEP_TIME"
  done
  echo "($ME) $(date) .once script executed."
else
  echo "($ME) $(date) No .once script (or not first incarnation)."
fi
echo "($ME) $(date) Touching $ONCE_EXECUTED_FILE..."
touch "$ONCE_EXECUTED_FILE"

# Always run the ALWAYS_SCRIPT...
if [ -f "$ALWAYS_SCRIPT" ]; then
  echo "($ME) $(date) Trying $ALWAYS_SCRIPT..."
  echo "[SCRIPT BEGIN]"
  cat "$ALWAYS_SCRIPT"
  echo "[SCRIPT END]"
  touch "$ALWAYS_STARTED_FILE"
  until /var/lib/neo4j/bin/cypher-shell -u neo4j -p "$GRAPH_PASSWORD" < "$ALWAYS_SCRIPT"
  do
    echo "($ME) $(date) No joy with .always, waiting and trying again..."
    sleep "$ACTION_SLEEP_TIME"
  done
  echo "($ME) $(date) .always script executed."
else
  echo "($ME) $(date) No .always script."
fi
echo "($ME) $(date) Touching $ALWAYS_EXECUTED_FILE..."
touch "$ALWAYS_EXECUTED_FILE"

echo "($ME) $(date) Finished."
