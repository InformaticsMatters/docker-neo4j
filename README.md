# The InformaticsMatters neo4j container image

[![CodeFactor](https://www.codefactor.io/repository/github/informaticsmatters/docker-neo4j/badge)](https://www.codefactor.io/repository/github/informaticsmatters/docker-neo4j)

A specialised build of neo4j used by a number of InformaticsMatters projects.

The repo contains image definitions for our Graph database and a loader
that populates the graph from an AWS S3 path.

## Prerequisites
You will need: -

- Docker compose (ideally v2)

## Building the images
To build and push the community, enterprise, and loader images...

```bash
docker compose build
docker compose push
```

## Building from a non-AMD platform (buildx)
If you are on an non-AMD platform you should use `docker buildx` to build the images for
AMD platforms. Here we're building the 4.4.37 image: -

```bash
TAG=4.4.37
docker buildx build . --platform linux/amd64 -t informaticsmatters/neo4j:${TAG}
docker buildx build . -f Dockerfile-enterprise --platform linux/amd64 -t informaticsmatters/neo4j:${TAG}-enterprise
docker buildx build . -f Dockerfile-s3-loader --platform linux/amd64 -t informaticsmatters/neo4j-s3-loader:${TAG}
```

And then push the cross-compiled images to Docker hub: -

```bash
docker push informaticsmatters/neo4j:${TAG}
docker push informaticsmatters/neo4j:${TAG}-enterprise
docker push informaticsmatters/neo4j-s3-loader:${TAG}
```

## Building against a new neo4j base image
When creating new versions of the images create a new branch (we have a branch
for each neo4j version we build). You should then adjust the corresponding
tags in the `docker-compose.yml` file to match the branch name you've chosen,
and the tags in the `Dockerfile` and `Dockerfile-enterprise` files so they pull from
the correct image sources.

Remember that in each version you need to make changes to the `docker-entrypoint.sh`
script. Sections between the `IM-BEGIN` and `IM-END` comments (inclusive)
are our sections that need to be grafted into a copy of the entrypoint
for the neo4j image you are building for. See the **docker-entrypoint tweaks** section
below.

## Typical execution (Docker)
Assuming you have a set of fragment graph files, start by creating three directories
that we'll use to mount into the container image: -

1.  A data directory (i.e. `~/neo4j-import`) with graph files and a pre-start
    batch loader script in it called `load-neo4j.sh`
1.  A directory for logs (i.e. `~/neo4j-container-logs`)
1.  A directory to mount for the generated Neo4j database
    (i.e. `~/neo4j-container-graph`)

>   You will need to change the `--ignore-missing-nodes` command option in the
    batch loader script to `--skip-bad-relationships` if you have a script
    that was compiled for neo4j v3.

>   Depending on the _integrity_ of your graph, if you have duplicate nodes
    (and you shouldn't) you might need to add `--skip-duplicate-nodes to your
    `load-neo4j.sh` import command.

With directories and data in place you should be able to start the database
with the following docker command: -

    $ docker run --detach \
        -v $HOME/neo4j-import:/data-import \
        -v $HOME/neo4j-container-logs:/graph-logs \
        -v $HOME/neo4j-container-graph:/data \
        -p 7474:7474 \
        -p 7687:7687 \
        -e CYPHER_ROOT=/data \
        -e EXTENSION_SCRIPT=/data-import/load-neo4j.sh \
        -e FORCE_EARLY_READINESS=yes \
        -e GRAPH_PASSWORD=blob1234 \
        -e IMPORT_DIRECTORY=/data-import \
        -e IMPORT_TO=graph \
        -e NEO4J_AUTH=neo4j/blob1234 \
        -e NEO4J_USERNAME=neo4j \
        -e NEO4J_dbms_directories_data=/data \
        -e NEO4J_dbms_directories_logs=/graph-logs \
        informaticsmatters/neo4j:4.4.37

Monitor the logs when the container's running to ensure the database build,
which can take considerable time for non-trivial graphs, progresses without error: -

    $ docker logs -f <container-id>

## Running post-DB cypher commands
The image contains the ability to run a series of cypher commands
after the database has started. It achieves this by running a provided
`cypher-runner.sh` script located in this image's `/cypher-runner` directory.
This script is executed towards the end of the `docker-entrypoint.sh`
and runs in the background until the provided cypher commands have been
executed.

All you need to do to run your own early cypher commands
is to provide them in either a `/cypher-runner/cypher-script.once`
or `/cypher-runner/cypher-script.always` file and provide
the neo4j credentials.

An example `.once` script may contain the following index commands: -

    CREATE INDEX ON :F2(smiles);
    CREATE INDEX ON :VENDOR(cmpd_id);

An example `.always` script may contain the following cache-warm-up commands: -

    CALL apoc.warmup.run(true, true, true);

>   This command helps improve query performance by quickly [warming up] the
    page-cache by touching pages in parallel optionally loading
    property-records, dynamic-properties and indexes

If the environment variables `NEO4J_USERNAME` and `NEO4J_PASSWORD` are defined,
the scripts will be run in the background automatically.

>   The cypher runner waits for a short period of time after neo4j has been
    given an opportunity to start (about 60 seconds) before the first run of
    the script is attempted. This can be configured in the image (refer
    to the cypher-runner script for the environment variables it inspects).

## docker-entrypoint tweaks
**CAUTION**: We replace the supplied neo4h `docker-entrypoint.sh` script with
our own variant. It adds some extra logic, all identified and briefly documents
by comments that begin `IM-BEGIN` and end with `IM-END`.

## Plugins
We've added the following plugins to the image: -

1.  **Neo4j Graph Data Science Library** [gds] from the [community] section of
    the download-centre
    (formally the graph-algorithms-algo library we used in our 3.5 image)
2.  **Neo4j Apoc Procedure**, a collection of useful Neo4j Procedures
    from the [apoc] distribution on Maven.

>   The changes to `dbms.security.procedures.unrestricted` take place in the
    **Dockerfile** where it's written to `/var/lib/neo4j/conf/neo4j.conf`.

## The enterprise container image
Although a build is made available for the Enterprise container
you are not permitted to use it unless you are in possession of a
valid neo4j licence agreement.

## The ansible role and playbook
The Ansible role and corresponding playbook has been written to simplify
deployment of the neo4j image along with an associated AWS S3-based graph.

The role deploys an S3-based loader prior to spinning-up the neo4j instance.

---

[apoc]: https://mvnrepository.com/artifact/org.neo4j.procedure/apoc
[gds]: https://neo4j.com/docs/graph-data-science/current/installation/
[community]: https://neo4j.com/download-center/#community
[warming up]: https://neo4j-contrib.github.io/neo4j-apoc-procedures/3.5/operational/warmup/
