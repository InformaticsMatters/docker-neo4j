FROM neo4j:4.2.1

COPY ./docker-entrypoint.sh /
COPY readiness-probe.sh /
COPY ./files/*.jar /var/lib/neo4j/plugins/

# Our cypher-runner.
# Expected by and employed by our 'load-neo4j' strategy.
# The user puts their cypher script into the file
# /cypher-script/cypher.script and the runner runs it (driven by the loader)
COPY cypher-runner.sh /cypher-runner/

RUN mkdir /cypher-script && \
    chmod 755 /cypher-runner/cypher-runner.sh && \
    chmod 755 /*.sh && \
    chmod 744 /cypher-script && \
    echo 'dbms.security.procedures.unrestricted=algo.*,apoc.*' >> /var/lib/neo4j/conf/neo4j.conf

ENV NEO4J_EDITION community
