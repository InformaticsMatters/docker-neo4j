#!/bin/sh

# We need some key environment variables
# before we do anything sensible...
#
# AWS_*         Are AWS credentials for accessing the S3 bucket
# APP_ROOT      The path to the application root directory
# CYPHER_ROOT   The path to the cypher script directory (typically /data)
# GRAPH_WIPE    If 'yes' the compiled graph is erased, forcing
#               a resync with S3 and a reload of the Graph data.
#               Compiled graph data is also erased if the file /data/WIPE exists
#               (which is then itself removed)
# POST_SLEEP_S  A value (seconds) to sleep at the end of the script.
#               this allows the user to inspect the environment prior
#               to the execution moving to the graph container.
# SYNC_PATH     Is the directory to synchronise S3 content with
#               Typically the data-loader directory

: "${AWS_ACCESS_KEY_ID?Need to set AWS_ACCESS_KEY_ID}"
: "${AWS_SECRET_ACCESS_KEY?Need to set AWS_SECRET_ACCESS_KEY}"
: "${AWS_BUCKET?Need to set AWS_BUCKET}"
: "${AWS_BUCKET_PATH?Need to set AWS_BUCKET_PATH}"
: "${APP_ROOT?Need to set APP_ROOT}"
: "${CYPHER_ROOT?Need to set CYPHER_ROOT}"
: "${EXTENSION_SCRIPT?Need to set EXTENSION_SCRIPT}"
: "${GRAPH_WIPE?Need to set GRAPH_WIPE}"
: "${SYNC_PATH?Need to set SYNC_PATH}"

ME=s3-loader-entrypoint.sh

# If GRAPH_WIPE is 'yes' or the file /data/WIPE exists
# then the compiled database directory is erased prior to running the S3 sync.
if [ "$GRAPH_WIPE" = "yes" ] || [ -f "/data/WIPE" ]; then
  echo "($ME) $(date) Wiping graph data (GRAPH_WIPE=$GRAPH_WIPE or /data/WIPE exists)..."
  rm -rf /data/data/*
  rm -f /data/WIPE
else
  echo "($ME) $(date) Preserving existing graph data (GRAPH_WIPE=$GRAPH_WIPE)"
fi

# Where are the scripts (and '.executed') files kept?
CYPHER_PATH="$CYPHER_ROOT/cypher-script"
echo "($ME) $(date) Making cypher path directory ($CYPHER_PATH)..."
mkdir -p "$CYPHER_PATH"

# We only pull down data if it looks like the sync-path has no loader script.
# Pulling down data again is time-consuming and we insect the
# files in the loader script later in this script...
LOAD_SCRIPT=load-neo4j.sh
if [ ! -f "/data/${SYNC_PATH}/${LOAD_SCRIPT}" ]; then

  # Remove any 'always.executed' file.
  # This will be re-created by the graph container
  # when the 'always script' finishes.
  ALWAYS_EXECUTED_FILE="$CYPHER_PATH/always.executed"
  if [ -n "$ALWAYS_EXECUTED_FILE" ]; then
    echo "($ME) $(date) Removing always executed file ($ALWAYS_EXECUTED_FILE)"
    rm -f "$ALWAYS_EXECUTED_FILE" || true
  fi

  # Now copy recursively to the local SYNC_PATH
  echo "($ME) $(date) Copying objects from 's3://${AWS_BUCKET}/${AWS_BUCKET_PATH}'..."
  aws s3 cp \
    "s3://${AWS_BUCKET}/${AWS_BUCKET_PATH}/" \
    "/data/${SYNC_PATH}/" \
    --recursive \
    --exclude '*/combined/*'

  # Run the 'hash prep' script if a hash5 directory exists in the download.
  # It concatenates all the hash files to form the (missing) node and edge csv.gz files.
  if [ -d "/data/${SYNC_PATH}/hash5" ]; then
    echo "($ME) $(date) Running '${APP_ROOT}/hash-prep.sh /data/${SYNC_PATH}'..."
    ${APP_ROOT}/hash-prep.sh /data/${SYNC_PATH}
  fi

  echo "($ME) $(date) Download and preparation complete."

else

  echo "($ME) $(date) Skipping download - ${LOAD_SCRIPT} exists"

fi

# Where will the database appear?
# Only interested in this if there's a CYPHER_ROOT
# (i.e. we're dealing with neo4j)
if [ -n "$CYPHER_ROOT" ]; then
  echo "($ME) $(date) Making ultimate data directory (/data/data)..."
  mkdir -p "/data/data"
fi

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

# Has a POST_SLEEP_S been defined?
if [ "$POST_SLEEP_S" ]; then
  echo "($ME) $(date) POST_SLEEP_S=$POST_SLEEP_S sleeping..."
  sleep "$POST_SLEEP_S"
  echo "($ME) $(date) Slept."
else
  echo "($ME) $(date) POST_SLEEP_S is not defined - leaving now..."
fi

echo "($ME) $(date) That's All Folks!"
