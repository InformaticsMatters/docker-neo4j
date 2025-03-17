#!/usr/bin/env bash
#
# A 'prep' script, given a 'prepared' dataset
# that has been extracted to a bucket and path on S3.
# This script concatenates the hash files (on a per-file basis)
# and then creates a 'load-neo4j.sh' script that will be used
# to import the data into Neo4j.

# Move to download directory
# --------------------------
cd $1

# Collect all the hashes together
# -------------------------------
for dir in hash5/*/; do
  if [ -d "${dir}prepared" ]; then
    name=$(echo "${dir}" | cut -f2 -d/)
    target_file="${name}.csv.gz"
    echo "" > ${target_file}
    for hash_file in "${dir}prepared"/*; do
      cat ${hash_file} >> ${target_file}
    done
  fi
done

# Create load-neo4j.sh TOP
# ------------------------
cat > load-neo4j.sh << LOAD_A
#!/usr/bin/env bash

ME=load-neo4j.sh

# Some entry diagnostics.
# Display key variables and the database and import directories...
echo "($ME) $(date) Running as $(id)"
echo "($ME) $(date) Starting (from $IMPORT_DIRECTORY)..."
echo "($ME) $(date) Importing to database $IMPORT_TO"
echo "($ME) $(date) Database root is $NEO4J_dbms_directories_data"
echo "($ME) $(date) Database root content is..."
ls -l $NEO4J_dbms_directories_data
if [ -d $NEO4J_dbms_directories_data/databases ]
then
    echo "($ME) $(date) Database root databases content is..."
    ls -l $NEO4J_dbms_directories_data/databases
fi
echo "($ME) $(date) Import content is..."
ls -l $IMPORT_DIRECTORY

# If the destination database exists
# then do nothing...
if [ ! -d $NEO4J_dbms_directories_data/databases/$IMPORT_TO.db ]
then
    echo "($ME) $(date) Importing into '$NEO4J_dbms_directories_data/databases/$IMPORT_TO.db'..."

    cd $IMPORT_DIRECTORY
    /var/lib/neo4j/bin/neo4j-admin import \\
        --database $IMPORT_TO.db \\
LOAD_A

# Create the node/relationship CONTENT
# ------------------------------------
# Collect all the .csv.gz files
# and create --nodes or --relationships lines
# treating the last file separately
# (to deal with the training '\' correctly)
gz_files=(*.csv.gz)
for n_or_e_file in "${gz_files[@]::${#gz_files[@]}-1}"; do
  hdr=$(echo ${n_or_e_file} | sed 's/.gz//')
  if [[ $n_or_e_file =~ "nodes" ]]; then
    echo "        --nodes \"header-${hdr},${n_or_e_file}\" \\" >> load-neo4j.sh
  else
    echo "        --relationships \"header-${hdr},${n_or_e_file}\" \\" >> load-neo4j.sh
  fi
done
last_file="${gz_files[@]: -1:1}"
if [[ $last_file =~ "nodes" ]]; then
  echo "        --nodes \"header-${hdr},${n_or_e_file}\"" >> load-neo4j.sh
else
  echo "        --relationships \"header-${hdr},${n_or_e_file}\"" >> load-neo4j.sh
fi

# Create load-neo4j.sh BOTTOM
# ---------------------------
cat >> load-neo4j.sh << LOAD_B

    echo "($ME) $(date) Imported."
else
    echo "($ME) $(date) Database '$IMPORT_TO' already exists."
fi

echo "($ME) $(date) Finished."
LOAD_B

# Now remove the source hash files (to save space)
# ------------------------------------------------
rm -rf hash5
