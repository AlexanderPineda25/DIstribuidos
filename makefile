CC = gcc
CFLAGS = -O2 -Wall -Iinclude $(shell pkg-config --cflags libpq)
LDFLAGS = $(shell pkg-config --libs libpq) -lpthread -lhiredis

SRCS = src/db.c src/prime.c src/server.c src/mongoose.c
WORKER_SRCS = src/db.c src/prime.c src/worker.c
OBJS = $(SRCS:.c=.o)
WORKER_OBJS = $(WORKER_SRCS:.c=.o)

all: server worker

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

server: src/db.o src/prime.o src/server.o src/mongoose.o
	$(CC) -o server src/db.o src/prime.o src/server.o src/mongoose.o $(LDFLAGS)

worker: src/db.o src/prime.o src/worker.o
	$(CC) -o worker src/db.o src/prime.o src/worker.o $(LDFLAGS)

clean:
	rm -f src/*.o server worker
