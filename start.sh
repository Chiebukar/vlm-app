#!/bin/sh
# start.sh - start llama-server (background) then start Flask proxy

# allow overriding ports via env
LLAMA_PORT=${LLAMA_PORT:-8081}
export LLAMA_PORT

# run the flask server (server.py will spawn llama-server)
python3 /app/web/server.py
