FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install deps
RUN apt-get update && apt-get install -y \
    git build-essential cmake python3 python3-pip curl wget libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir huggingface_hub

WORKDIR /app
RUN git clone https://github.com/ggerganov/llama.cpp.git
WORKDIR /app/llama.cpp

# Build llama.cpp with server
RUN cmake -S . -B build -DLLAMA_CUBLAS=OFF -DLLAMA_BUILD_SERVER=ON \
    && cmake --build build -j \
    && cp build/bin/llama-server /usr/local/bin/llama-server

WORKDIR /app
# Download model
RUN huggingface-cli download ggml-org/SmolVLM-500M-Instruct-GGUF \
    --local-dir /app/SmolVLM-500M-Instruct-GGUF

# Copy frontend
COPY index.html /app/web/index.html

# Expose Render port
EXPOSE 10000
ENV PORT=10000

# Run llama-server (it can serve static files from --static)
CMD llama-server \
    -m /app/SmolVLM-500M-Instruct-GGUF/SmolVLM-500M-Instruct-Q8_0.gguf \
    --mmproj /app/SmolVLM-500M-Instruct-GGUF/mmproj-SmolVLM-500M-Instruct-Q8_0.gguf \
    --host 0.0.0.0 --port $PORT \
    --static /app/web
