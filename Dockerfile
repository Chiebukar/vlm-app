# ---------- Stage 1: build llama-server ----------
FROM ubuntu:22.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential cmake git wget curl unzip \
    libssl-dev pkg-config python3 python3-pip \
    libevent-dev libmicrohttpd-dev libcurl4-openssl-dev \
    clang lld \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN git clone https://github.com/ggerganov/llama.cpp.git

WORKDIR /app/llama.cpp
# Build only the server target (faster)
RUN cmake -S . -B build -DLLAMA_CUBLAS=OFF -DBUILD_SERVER=ON \
    && cmake --build build -j --target llama-server \
    && cp build/bin/llama-server /usr/local/bin/llama-server

# ---------- Stage 2: runtime ----------
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive PORT=8000

# runtime libs (llama-server needs libcurl / microhttpd, etc.)
RUN apt-get update && apt-get install -y \
    python3 python3-pip curl ca-certificates \
    libcurl4 libmicrohttpd12 libevent-2.1-7 \
    && rm -rf /var/lib/apt/lists/*

# bring in the built server binary
COPY --from=builder /usr/local/bin/llama-server /usr/local/bin/llama-server

WORKDIR /app
# install python deps for the tiny Flask proxy + downloader
RUN pip3 install --no-cache-dir flask requests huggingface_hub

# Download SmolVLM model (downloads at build-time and is baked into the image)
RUN huggingface-cli download ggml-org/SmolVLM-500M-Instruct-GGUF --local-dir /app/model

# copy web UI + server script + start script
COPY index.html /app/web/index.html
COPY server.py /app/web/server.py
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

EXPOSE ${PORT}
CMD ["/app/start.sh"]
