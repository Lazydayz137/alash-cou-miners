ARG XMRIG_VERSION=6.22.2
ARG SRBMINER_VERSION=2.7.5
ARG XMRIG_SHA256=""
ARG SRBMINER_SHA256=""

FROM debian:bookworm-slim AS downloader
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl tar gzip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /downloads

ARG XMRIG_VERSION
ARG XMRIG_SHA256
RUN set -eux; \
    curl -fsSL -o xmrig.tar.gz \
        "https://github.com/xmrig/xmrig/releases/download/v${XMRIG_VERSION}/xmrig-${XMRIG_VERSION}-linux-static-x64.tar.gz"; \
    if [ -n "${XMRIG_SHA256}" ]; then \
        echo "${XMRIG_SHA256}  xmrig.tar.gz" | sha256sum -c -; \
    else \
        echo "WARNING: XMRIG_SHA256 not set"; \
    fi; \
    tar -xzf xmrig.tar.gz; \
    cp "xmrig-${XMRIG_VERSION}/xmrig" /downloads/xmrig; \
    chmod +x /downloads/xmrig; \
    /downloads/xmrig --version | head -1

ARG SRBMINER_VERSION
ARG SRBMINER_SHA256
RUN set -eux; \
    SRB_DASH=$(echo "${SRBMINER_VERSION}" | tr '.' '-'); \
    curl -fsSL -o srb.tar.gz \
        "https://github.com/doktor83/SRBMiner-Multi/releases/download/${SRBMINER_VERSION}/SRBMiner-Multi-${SRB_DASH}-Linux.tar.gz"; \
    if [ -n "${SRBMINER_SHA256}" ]; then \
        echo "${SRBMINER_SHA256}  srb.tar.gz" | sha256sum -c -; \
    else \
        echo "WARNING: SRBMINER_SHA256 not set"; \
    fi; \
    mkdir -p srb && tar -xzf srb.tar.gz -C srb; \
    SRB_BIN=$(find srb -type f -name 'SRBMiner-MULTI' | head -1); \
    cp "$SRB_BIN" /downloads/SRBMiner-MULTI; \
    chmod +x /downloads/SRBMiner-MULTI

FROM debian:bookworm-slim AS cpuminer-build
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential automake autoconf pkg-config \
        libcurl4-openssl-dev libssl-dev libjansson-dev libgmp-dev zlib1g-dev \
        git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone --depth 1 https://github.com/JayDDee/cpuminer-opt.git
WORKDIR /src/cpuminer-opt
RUN ./build.sh && cp cpuminer /cpuminer && /cpuminer --version | head -1

FROM debian:bookworm-slim
LABEL org.opencontainers.image.title="akash-cpu-miners" \
      org.opencontainers.image.source="https://github.com/lazydayz137/akash-cpu-miners"

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates coreutils procps util-linux \
        libcurl4 libssl3 libjansson4 libgmp10 libgomp1 zlib1g \
    && rm -rf /var/lib/apt/lists/*

COPY --from=downloader     /downloads/xmrig          /usr/local/bin/xmrig
COPY --from=downloader     /downloads/SRBMiner-MULTI /usr/local/bin/SRBMiner-MULTI
COPY --from=cpuminer-build /cpuminer                 /usr/local/bin/cpuminer

RUN ln -s /usr/local/bin/xmrig    /xmrig \
 && ln -s /usr/local/bin/cpuminer /usr/local/bin/cpuminer-opt

WORKDIR /work
CMD ["/bin/sh"]
