#!/bin/bash
# scripts/start-stack.sh

COMPOSE_FILES="-f docker-compose.yml"

# Add compose files based on what you want to run
for file in compose/*.yml; do
    COMPOSE_FILES="$COMPOSE_FILES -f $file"
done

docker compose $COMPOSE_FILES "$@"