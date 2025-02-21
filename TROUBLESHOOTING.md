# Troubleshooting Guide

## Something went wrong in the import
Neo4j doesn't like imports with duplicates of bad relationships.
This can impair performance.

The import progress is written to stdout and is not captured in the logs.
If you have access to the stdout, that's great, start there.
If not you might find something in the *import report*. In our Kubernetes
deployment this is typically written to `/data/data-loader/import.report`
(unless redirected by the `load-neo4j.sh` script in that directory).

## Resetting the neo4j password
-   Enter the graph container in the Pod
-   Remove the file `/data/data/dbms/auth`
-   Restart the Pod (by killing it or scaling up/down using the StatefulSet)

Then, from another Pod (one with curl) you can set the password to something
else. Here we set it to `pilotvolume`: -

    $ curl -H "Content-Type: application/json" \
        -X POST \
        -d '{"password":"pilotvolume"}' \
        -u neo4j:neo4j \
        http://graph-http.graph.svc:7474/user/neo4j/password

>   You can only set the password once

## Rebuilding the database
If you want to rebuild the database (but not download the original CSV files)
then you just need to remove the compiled database files (along with any
existing `auth` file).

From graph Pod...

-   Remove the directory `/data/data/databases`
-   Remove the file `/data/data/dbms/auth`
-   Restart the Pod (by killing it or scaling up/down using the StatefulSet)

>   Be aware that a significant database may take a number of hours
    to build. At the very least, when using a fast local volume, set-aside
    at least an hour.

## Creating the 'standard' indexes
-   Enter the graph container in the Pod
-   Enter the cypher-shell with `/var/lib/neo4j/bin/cypher-shell -u neo4j -p <PASSWORD>`
-   From the `neo4j>` prompt: -
    -   Run `CALL db.indexes();` to display the current indexes
    -   Run `CREATE INDEX ON :F2(smiles);` to build the `F2` index
    -   Run `CREATE INDEX ON :VENDOR(cmpd_id);` to build the `VENDOR` index
    -   Wait until the indexes have been built with repeated use of `CALL db.indexes();`
-   Exit from the shell with `:exit`

## Priming the database cache
Assuming indexes have been built
(you must wait for them if they are being built) you can...

-   Enter the graph container in the Pod
-   Enter the cypher-shell with `/var/lib/neo4j/bin/cypher-shell -u neo4j -p <PASSWORD>`
-   From the `neo4j>` prompt: -
    -   Run `CALL apoc.warmup.run(true, true, true);`
-   Exit from the shell with `:exit`

>   Building the cache will take significant time.

---
