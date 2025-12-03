#define _POSIX_C_SOURCE 200809L
#include "db.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <hiredis/hiredis.h>

static char *conninfo_global = NULL;
static __thread PGconn *thread_conn = NULL;
static redisContext *redis_global = NULL;

static PGconn *get_conn(void) {
    if (thread_conn) return thread_conn;
    if (!conninfo_global) {
        fprintf(stderr, "db not initialized (no conninfo)\n");
        return NULL;
    }
    thread_conn = PQconnectdb(conninfo_global);
    if (PQstatus(thread_conn) != CONNECTION_OK) {
        fprintf(stderr, "Thread DB connect error: %s\n", PQerrorMessage(thread_conn));
        PQfinish(thread_conn);
        thread_conn = NULL;
        return NULL;
    }
    return thread_conn;
}

int db_init(const char *conninfo) {
    if (conninfo_global) free(conninfo_global);
    conninfo_global = strdup(conninfo);
    if (!conninfo_global) return -1;
    PGconn *c = PQconnectdb(conninfo_global);
    if (PQstatus(c) != CONNECTION_OK) {
        fprintf(stderr, "DB connect error: %s\n", PQerrorMessage(c));
        PQfinish(c);
        return -1;
    }
    PQfinish(c);
    return 0;
}

void db_set_redis(redisContext *redis) {
    redis_global = redis;
}

void db_close() {
    if (conninfo_global) { free(conninfo_global); conninfo_global = NULL; }
    if (thread_conn) { PQfinish(thread_conn); thread_conn = NULL; }
    if (redis_global) { redisFree(redis_global); redis_global = NULL; }
}

PGconn *db_open_connection(const char *conninfo) {
    PGconn *c = PQconnectdb(conninfo);
    if (PQstatus(c) != CONNECTION_OK) {
        fprintf(stderr, "DB connection error: %s\n", PQerrorMessage(c));
        PQfinish(c);
        return NULL;
    }
    return c;
}

void db_close_connection(PGconn *c) {
    if (c) PQfinish(c);
}


int db_create_solicitud_and_enqueue(char *out_id, int cantidad, int digitos) {
    int rc = -1;
    PGconn *c = get_conn();
    if (!c) return -1;

    PGresult *res = PQexec(c, "BEGIN");
    if (PQresultStatus(res) != PGRES_COMMAND_OK) { PQclear(res); return -1; }
    PQclear(res);

    char cant_str[32], digs_str[32];
    snprintf(cant_str, sizeof(cant_str), "%d", cantidad);
    snprintf(digs_str, sizeof(digs_str), "%d", digitos);
    const char *paramValues[2] = { cant_str, digs_str };
    
    res = PQexecParams(c,
        "INSERT INTO solicitudes (cantidad, digitos) VALUES ($1::int, $2::int) RETURNING id",
        2, NULL, paramValues, NULL, NULL, 0);
    
    if (PQresultStatus(res) != PGRES_TUPLES_OK) { 
        fprintf(stderr,"DB error: %s\n", PQerrorMessage(c)); 
        PQclear(res); 
        PQexec(c,"ROLLBACK"); 
        return -1; 
    }
    
    char *id = PQgetvalue(res,0,0);
    strncpy(out_id, id, 37);
    out_id[36] = '\0';
    PQclear(res);

    res = PQexec(c, "COMMIT");
    PQclear(res);

    if (redis_global) {
        char job_str[256];
        snprintf(job_str, sizeof(job_str), "%s:%d:%d", out_id, cantidad, digitos);
        redisReply *reply = redisCommand(redis_global, "LPUSH primes:queue %s", job_str);
        if (!reply) {
            fprintf(stderr, "Redis LPUSH error\n");
            return -1;
        }
        freeReplyObject(reply);
    }

    rc = 0;
    return rc;
}


int db_fetch_job_for_worker(char *out_job_id, char *out_solicitud_id, int *out_cantidad, int *out_digitos) {
    int rc = -1;
    PGconn *c = get_conn();
    if (!c) return -1;

    PGresult *res = PQexec(c, "BEGIN");
    if (PQresultStatus(res) != PGRES_COMMAND_OK) { PQclear(res); return -1; }
    PQclear(res);

    PGresult *r = PQexec(c,
        "SELECT id::text, solicitud_id::text, cantidad, digitos FROM cola WHERE procesado = FALSE FOR UPDATE SKIP LOCKED LIMIT 1");
    if (PQresultStatus(r) != PGRES_TUPLES_OK) { PQclear(r); PQexec(c,"ROLLBACK"); return -1; }
    if (PQntuples(r) == 0) {
        PQclear(r);
        PQexec(c, "ROLLBACK");
        return 1;
    }
    const char *job_id = PQgetvalue(r,0,0);
    const char *sol_id = PQgetvalue(r,0,1);
    int cantidad = atoi(PQgetvalue(r,0,2));
    int digitos = atoi(PQgetvalue(r,0,3));
    strncpy(out_job_id, job_id, 37);
    out_job_id[36] = '\0';
    strncpy(out_solicitud_id, sol_id, 37);
    out_solicitud_id[36] = '\0';
    *out_cantidad = cantidad;
    *out_digitos = digitos;
    PQclear(r);

    const char *paramValues[1] = { out_job_id };
    PGresult *u = PQexecParams(c,
        "UPDATE cola SET procesado = TRUE WHERE id = $1::uuid",
        1, NULL, paramValues, NULL, NULL, 0);
    if (PQresultStatus(u) != PGRES_COMMAND_OK) { fprintf(stderr,"DB error: %s\n", PQerrorMessage(c)); PQclear(u); PQexec(c,"ROLLBACK"); return -1; }
    PQclear(u);

    PGresult *cm = PQexec(c, "COMMIT");
    PQclear(cm);
    rc = 0;
    return rc;
}

int db_mark_job_done(const char *job_id) {
    PGconn *c = get_conn();
    if (!c) return -1;
    const char *paramValues[1] = { job_id };
    PGresult *r = PQexecParams(c,
        "DELETE FROM cola WHERE id = $1::uuid",
        1, NULL, paramValues, NULL, NULL, 0);
    if (PQresultStatus(r) != PGRES_COMMAND_OK) { PQclear(r); return -1; }
    PQclear(r);
    return 0;
}

int db_insert_result(const char *solicitud_id, const char *primo) {
    int rc = -1;
    PGconn *c = get_conn();
    if (!c) return -1;
    const char *paramValues[2] = { solicitud_id, primo };
    PGresult *r = PQexecParams(c,
        "INSERT INTO resultados (solicitud_id, primo) VALUES ($1::uuid, $2::text)",
        2, NULL, paramValues, NULL, NULL, 0);
    if (PQresultStatus(r) != PGRES_COMMAND_OK) {
        if (strstr(PQerrorMessage(c), "duplicate key") != NULL ||
            strstr(PQerrorMessage(c), "unique") != NULL) {
            PQclear(r);
            rc = -2;
            return rc;
        }
        fprintf(stderr, "db_insert_result error: %s\n", PQerrorMessage(c));
        PQclear(r);
        return -1;
    }
    PQclear(r);
    return 0;
}

int db_inc_generado(const char *solicitud_id) {
    PGconn *c = get_conn();
    if (!c) return -1;
    const char *paramValues[1] = { solicitud_id };
    PGresult *r = PQexecParams(c,
        "UPDATE solicitudes SET generados = generados + 1 WHERE id = $1::uuid",
        1, NULL, paramValues, NULL, NULL, 0);
    if (PQresultStatus(r) != PGRES_COMMAND_OK) { PQclear(r); return -1; }
    PQclear(r);
    return 0;
}

int db_get_status(const char *solicitud_id, int *cantidad, int *digitos, int *generados) {
    PGconn *c = get_conn();
    if (!c) return -1;
    const char *paramValues[1] = { solicitud_id };
    PGresult *r = PQexecParams(c,
        "SELECT cantidad, digitos, generados FROM solicitudes WHERE id = $1::uuid",
        1, NULL, paramValues, NULL, NULL, 0);
    if (PQresultStatus(r) != PGRES_TUPLES_OK) { PQclear(r); return -1; }
    if (PQntuples(r) == 0) { PQclear(r); return -2; }
    *cantidad = atoi(PQgetvalue(r,0,0));
    *digitos = atoi(PQgetvalue(r,0,1));
    *generados = atoi(PQgetvalue(r,0,2));
    PQclear(r);
    return 0;
}

char ** db_get_results(const char *solicitud_id, int *count) {
    const char *paramValues[1] = { solicitud_id };
    PGconn *c = get_conn();
    if (!c) { *count = -1; return NULL; }
    PGresult *r = PQexecParams(c,
        "SELECT primo FROM resultados WHERE solicitud_id = $1::uuid",
        1, NULL, paramValues, NULL, NULL, 0);
    if (PQresultStatus(r) != PGRES_TUPLES_OK) { PQclear(r); *count = -1; return NULL; }
    int n = PQntuples(r);
    char **arr = malloc(sizeof(char*) * n);
    for (int i=0;i<n;++i) arr[i] = strdup(PQgetvalue(r,i,0));
    PQclear(r);
    *count = n;
    return arr;
}

void db_free_results(char **arr, int count) {
    for (int i=0;i<count;++i) free(arr[i]);
    free(arr);
}

int db_fetch_job_for_worker_conn(PGconn *c, char *out_job_id, char *out_solicitud_id, int *out_cantidad, int *out_digitos) {
    if (!c) return -1;
    int rc = -1;

    PGresult *res = PQexec(c, "BEGIN");
    if (PQresultStatus(res) != PGRES_COMMAND_OK) { PQclear(res); return -1; }
    PQclear(res);

    PGresult *r = PQexec(c,
        "SELECT id::text, solicitud_id::text, cantidad, digitos FROM cola WHERE procesado = FALSE FOR UPDATE SKIP LOCKED LIMIT 1");
    if (PQresultStatus(r) != PGRES_TUPLES_OK) { PQclear(r); PQexec(c,"ROLLBACK"); return -1; }
    if (PQntuples(r) == 0) {
        PQclear(r);
        PQexec(c, "ROLLBACK");
        return 1;
    }
    const char *job_id = PQgetvalue(r,0,0);
    const char *sol_id = PQgetvalue(r,0,1);
    int cantidad = atoi(PQgetvalue(r,0,2));
    int digitos = atoi(PQgetvalue(r,0,3));
    strncpy(out_job_id, job_id, 37);
    out_job_id[36] = '\0';
    strncpy(out_solicitud_id, sol_id, 37);
    out_solicitud_id[36] = '\0';
    *out_cantidad = cantidad;
    *out_digitos = digitos;
    PQclear(r);

    const char *paramValues[1] = { out_job_id };
    PGresult *u = PQexecParams(c,
        "UPDATE cola SET procesado = TRUE WHERE id = $1::uuid",
        1, NULL, paramValues, NULL, NULL, 0);
    if (PQresultStatus(u) != PGRES_COMMAND_OK) { fprintf(stderr,"DB error: %s\n", PQerrorMessage(c)); PQclear(u); PQexec(c,"ROLLBACK"); return -1; }
    PQclear(u);

    PGresult *cm = PQexec(c, "COMMIT");
    PQclear(cm);
    rc = 0;
    return rc;
}

int db_mark_job_done_conn(PGconn *c, const char *job_id) {
    if (!c) return -1;
    const char *paramValues[1] = { job_id };
    PGresult *r = PQexecParams(c,
        "DELETE FROM cola WHERE id = $1::uuid",
        1, NULL, paramValues, NULL, NULL, 0);
    if (PQresultStatus(r) != PGRES_COMMAND_OK) { PQclear(r); return -1; }
    PQclear(r);
    return 0;
}

int db_insert_result_conn(PGconn *c, const char *solicitud_id, const char *primo) {
    if (!c) return -1;
    int rc = -1;
    const char *paramValues[2] = { solicitud_id, primo };
    PGresult *r = PQexecParams(c,
        "INSERT INTO resultados (solicitud_id, primo) VALUES ($1::uuid, $2::text)",
        2, NULL, paramValues, NULL, NULL, 0);
    if (PQresultStatus(r) != PGRES_COMMAND_OK) {
        if (strstr(PQerrorMessage(c), "duplicate key") != NULL ||
            strstr(PQerrorMessage(c), "unique") != NULL) {
            PQclear(r);
            rc = -2;
            return rc;
        }
        fprintf(stderr, "db_insert_result_conn error: %s\n", PQerrorMessage(c));
        PQclear(r);
        return -1;
    }
    PQclear(r);
    return 0;
}

int db_inc_generado_conn(PGconn *c, const char *solicitud_id) {
    if (!c) return -1;
    const char *paramValues[1] = { solicitud_id };
    PGresult *r = PQexecParams(c,
        "UPDATE solicitudes SET generados = generados + 1 WHERE id = $1::uuid",
        1, NULL, paramValues, NULL, NULL, 0);
    if (PQresultStatus(r) != PGRES_COMMAND_OK) { PQclear(r); return -1; }
    PQclear(r);
    return 0;
}
