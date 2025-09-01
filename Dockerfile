# -------------------------
# Stage 1: Build llama.cpp
# -------------------------
FROM ubuntu:22.04 AS builder

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential cmake git wget curl unzip \
    libssl-dev pkg-config python3 python3-pip \
    libevent-dev libmicrohttpd-dev \
    clang lld \
    && rm -rf /var/lib/apt/lists/*

# Clone llama.cpp (latest main)
WORKDIR /app
RUN git clone https://github.com/ggerganov/llama.cpp.git
WORKDIR /app/llama.cpp

# Build llama.cpp server
RUN cmake -S . -B build \
    -DLLAMA_CUBLAS=OFF \
    -DBUILD_SERVER=ON \
    && cmake --build build -j \
    && cp build/bin/llama-server /usr/local/bin/llama-server


# -------------------------
# Stage 2: Final runtime
# -------------------------
FROM ubuntu:22.04

# Install minimal runtime dependencies
RUN apt-get update && apt-get install -y \
    wget curl python3 python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Copy llama-server binary
COPY --from=builder /usr/local/bin/llama-server /usr/local/bin/llama-server

# Copy frontend files
WORKDIR /app/web
COPY index.html /app/web/index.html

# Install a lightweight web server (to serve index.html)
RUN pip3 install flask

# Add a simple Flask app that proxies llama-server and serves frontend
COPY <<EOF /app/web/server.py
from flask import Flask, send_from_directory, request, Response
import subprocess, threading

app = Flask(__name__, static_folder=".", static_url_path="")

# Start llama-server in background
def run_llama():
    subprocess.run(["llama-server", "-m", "/app/model/SmolVLM-500M-Instruct-GGUF/SmolVLM-500M-Instruct-Q4_K_M.gguf", "-c", "2048", "--host", "0.0.0.0", "--port", "8081"])

threading.Thread(target=run_llama, daemon=True).start()

@app.route("/")
def index():
    return send_from_directory(".", "index.html")

# Proxy API requests to llama-server
import requests
@app.route("/api/<path:path>", methods=["GET","POST"])
def proxy(path):
    url = f"http://127.0.0.1:8081/{path}"
    resp = requests.request(
        method=request.method,
        url=url,
        headers={key: value for (key, value) in request.headers if key.lower() != 'host'},
        data=request.get_data(),
        cookies=request.cookies,
        allow_redirects=False)
    excluded_headers = ['content-encoding', 'content-length', 'transfer-encoding', 'connection']
    headers = [(name, value) for (name, value) in resp.raw.headers.items() if name.lower() not in excluded_headers]
    return Response(resp.content, resp.status_code, headers)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(__import__('os').environ.get("PORT", 8000)))
EOF

# Default command for Render
CMD ["python3", "server.py"]
