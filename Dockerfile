# Use a lightweight Ubuntu base with dependencies
FROM ubuntu:22.04

# Set noninteractive mode for apt
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    git build-essential cmake python3 python3-pip curl wget \
    && rm -rf /var/lib/apt/lists/*

# Install Hugging Face CLI
RUN pip install --no-cache-dir huggingface_hub

# Clone llama.cpp
WORKDIR /app
RUN git clone https://github.com/ggerganov/llama.cpp.git
WORKDIR /app/llama.cpp

# Build llama.cpp with server enabled
RUN cmake -B build -DGGML_CUBLAS=OFF . && cmake --build build -j && \
    cp build/bin/llama-server /usr/local/bin/llama-server

# Download SmolVLM model
WORKDIR /app
RUN huggingface-cli download ggml-org/SmolVLM-500M-Instruct-GGUF \
    --local-dir /app/SmolVLM-500M-Instruct-GGUF

# Copy frontend (index.html etc.)
COPY index.html /app/index.html

# Expose ports: 8080 for llama-server, 8000 for webapp
EXPOSE 8080 8000

# Run both llama-server and simple Python webserver
CMD ./llama.cpp/build/bin/llama-server \
      -m /app/models/SmolVLM/SmolVLM-500M-Instruct-Q8_0.gguf \
      --host 0.0.0.0 --port 8080 --cors & \
    python3 -m http.server 8000 --bind 0.0.0.0
