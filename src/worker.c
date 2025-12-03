#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <hiredis/hiredis.h>
#include "db.h"
#include "prime.h"

static volatile int keep_running = 1;
static redisContext *redis_conn = NULL;
static const char *db_url = NULL;
static const char *redis_host = NULL;
static int redis_port = 0;

static void sigint_handler(int signo) {
    (void)signo;
    keep_running = 0;
    printf("[worker] Shutting down...\n");
}

redisContext *redis_connect(const char *host, int port) {
    redisContext *c = redisConnect(host, port);
    if (c == NULL || c->err) {
        fprintf(stderr, "[worker] Redis connection error: %s\n",
            c ? c->errstr : "Out of memory");
        if (c) redisFree(c);
        return NULL;
    }
    return c;
}

void redis_disconnect(redisContext *c) {
    if (c) redisFree(c);
}

int redis_get_job(redisContext *c, char *out_solicitud_id, int *out_cantidad, int *out_digitos) {
    redisReply *reply = redisCommand(c, "BLPOP primes:queue 5");
    if (!reply) {
        fprintf(stderr, "[worker] Redis error on BLPOP\n");
        return -1;
    }

    if (reply->type == REDIS_REPLY_NIL) {
        freeReplyObject(reply);
        return 1;
    }

    if (reply->type != REDIS_REPLY_ARRAY || reply->elements < 2) {
        fprintf(stderr, "[worker] Unexpected Redis response\n");
        freeReplyObject(reply);
        return -1;
    }

    const char *job_str = reply->element[1]->str;
    
    char solicitud_id[64], cantidad_str[32], digitos_str[32];
    if (sscanf(job_str, "%63[^:]:%31[^:]:%31s", solicitud_id, cantidad_str, digitos_str) != 3) {
        fprintf(stderr, "[worker] Failed to parse job: %s\n", job_str);
        freeReplyObject(reply);
        return -1;
    }

    strncpy(out_solicitud_id, solicitud_id, 63);
    out_solicitud_id[63] = '\0';
    *out_cantidad = atoi(cantidad_str);
    *out_digitos = atoi(digitos_str);

    freeReplyObject(reply);
    return 0;
}

int main(int argc, char **argv) {
    (void)argc; (void)argv;

    const char *db_env = getenv("DATABASE_URL");
    const char *redis_h = getenv("REDIS_HOST");
    const char *redis_p = getenv("REDIS_PORT");

    if (!db_env || !redis_h || !redis_p) {
        fprintf(stderr, "[worker] Missing env vars: DATABASE_URL, REDIS_HOST, REDIS_PORT\n");
        return 1;
    }

    db_url = db_env;
    redis_host = redis_h;
    redis_port = atoi(redis_p);

    if (db_init(db_url) != 0) {
        fprintf(stderr, "[worker] Failed to initialize database\n");
        return 1;
    }

    redis_conn = redis_connect(redis_host, redis_port);
    if (!redis_conn) {
        fprintf(stderr, "[worker] Failed to connect to Redis\n");
        db_close();
        return 1;
    }

    signal(SIGINT, sigint_handler);
    signal(SIGTERM, sigint_handler);

    printf("[worker] Started. DB: %s, Redis: %s:%d\n", db_url, redis_host, redis_port);

    while (keep_running) {
        char solicitud_id[64];
        int cantidad, digitos;

        int r = redis_get_job(redis_conn, solicitud_id, &cantidad, &digitos);
        if (r == 1) {
            continue;
        } else if (r != 0) {
            fprintf(stderr, "[worker] Failed to get job from Redis\n");
            sleep(1);
            continue;
        }

        printf("[worker] Got job: solicitud_id=%s, cantidad=%d, digitos=%d\n",
            solicitud_id, cantidad, digitos);

        PGconn *worker_conn = db_open_connection(db_url);
        if (!worker_conn) {
            fprintf(stderr, "[worker] Failed to open DB connection\n");
            sleep(1);
            continue;
        }

        int found = 0;
        while (found < cantidad) {
            uint64_t cand = gen_random_of_digits(digitos);
            if (!is_probable_prime(cand)) continue;

            char *s = u64_to_str(cand);
            int ins = db_insert_result_conn(worker_conn, solicitud_id, s);

            if (ins == 0) {
                db_inc_generado_conn(worker_conn, solicitud_id);
                found++;
                printf("[worker] Found: %s (%d/%d)\n", s, found, cantidad);
            } else if (ins == -2) {
                continue;
            } else {
                fprintf(stderr, "[worker] Error inserting result\n");
            }
            free(s);
        }

        db_close_connection(worker_conn);
        printf("[worker] Job completed: solicitud_id=%s\n", solicitud_id);
    }

    printf("[worker] Shutting down gracefully...\n");
    redis_disconnect(redis_conn);
    db_close();
    return 0;
}
