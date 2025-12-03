FROM ubuntu:22.04 AS builder

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    make \
    pkg-config \
    libpq-dev \
    libhiredis-dev \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY makefile ./
COPY include/ include/
COPY src/ src/
COPY sql/ sql/

RUN if [ ! -f include/mongoose.h ]; then \
      curl -L -o include/mongoose.h https://raw.githubusercontent.com/cesanta/mongoose/master/mongoose.h && \
      echo "Downloaded mongoose.h"; \
    fi && \
    if [ ! -f src/mongoose.c ]; then \
      curl -L -o src/mongoose.c https://raw.githubusercontent.com/cesanta/mongoose/master/mongoose.c && \
      echo "Downloaded mongoose.c"; \
    fi

RUN make clean && make

FROM ubuntu:22.04 AS api

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    libhiredis0.14 \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1000 primes

WORKDIR /app

COPY --from=builder /app/server ./server
COPY sql/init.sql ./sql/init.sql

RUN chown -R primes:primes /app && chmod 755 /app/server

USER primes

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/ 2>/dev/null || exit 1

ENV PORT=8000

# Ejecutar el binario server (API REST)
CMD ["sh", "-c", "exec ./server"]

FROM ubuntu:22.04 AS worker

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    libhiredis0.14 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1000 primes

WORKDIR /app

COPY --from=builder /app/worker ./worker

RUN chown -R primes:primes /app && chmod 755 /app/worker

USER primes

# Ejecutar el binario worker (procesa jobs)
CMD ["sh", "-c", "exec ./worker"]
