#!/bin/sh

# We need some key environment variables
# before we do anything sensible...
#
# CYPHER_ROOT   The path to the cypher script directory (typically /data)
# NEO4j_AUTH    The neo4j user password
# POST_SLEEP_S  A value (seconds) to sleep at the end of the script.
#               This allows the user to inspect the environment prior
#               to the execution moving to the graph container.

: "${CYPHER_ROOT?Need to set CYPHER_ROOT}"
: "${NEO4J_AUTH?Need to set NEO4J_AUTH}"

ME=sidecar-entrypoint.sh

# Where are the scripts (and '.executed') files kept?
CYPHER_PATH="$CYPHER_ROOT/cypher-script"
echo "($ME) $(date) Making cypher path directory ($CYPHER_PATH)..."
mkdir -p "$CYPHER_PATH"

# If there's 'once' or 'always' content then place it
# in the expected location for the corresponding cypher scripts.
if [ "$CYPHER_ONCE_CONTENT" ]; then
  cypher_file=cypher-script.once
  echo "($ME) $(date) Writing $CYPHER_PATH/$cypher_file..."
  echo "$CYPHER_ONCE_CONTENT" > "$CYPHER_PATH/$cypher_file"
fi
if [ "$CYPHER_ALWAYS_CONTENT" ]; then
  cypher_file=cypher-script.always
  echo "($ME) $(date) Writing $CYPHER_PATH/$cypher_file..."
  echo "$CYPHER_ALWAYS_CONTENT" > "$CYPHER_PATH/$cypher_file"
fi

# Run the sidecar logic...
python sidecar.py

# Has a POST_SLEEP_S been defined?
if [ "$POST_SLEEP_S" ]; then
  echo "($ME) $(date) POST_SLEEP_S=$POST_SLEEP_S sleeping..."
  sleep "$POST_SLEEP_S"
  echo "($ME) $(date) Slept."
else
  echo "($ME) $(date) POST_SLEEP_S is not defined - leaving now..."
fi

echo "($ME) $(date) That's All Folks!"
