#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <unistd.h>
#include <hiredis/hiredis.h>
#include "db.h"
#include "mongoose.h"

#define DEFAULT_PORT "8000"

static struct mg_mgr mgr;
static volatile int keep_running = 1;
static const char *db_url = NULL;
static redisContext *redis_ctx = NULL;

static char *extract_field(const char *body, const char *field) {
    char pat[64];
    snprintf(pat, sizeof(pat), "\"%s\"", field);
    char *p = strstr(body, pat);
    if (!p) return NULL;
    p = strchr(p, ':');
    if (!p) return NULL;
    p++;
    while (*p == ' ' || *p == '\"') p++;
    int quoted = (*(p-1) == '\"');
    char *q = p;
    if (quoted) {
        q = strchr(p, '\"');
        if (!q) return NULL;
    } else {
        while (*q && *q != ',' && *q != '}' && *q != ' ') ++q;
    }
    size_t len = q - p;
    char *out = malloc(len+1);
    strncpy(out, p, len);
    out[len] = '\0';
    return out;
}

static void handle_new(struct mg_connection *c, struct mg_http_message *hm) {
    char body_copy[1024];
    size_t n = hm->body.len < sizeof(body_copy)-1 ? hm->body.len : sizeof(body_copy)-1;
    memcpy(body_copy, hm->body.buf, n);
    body_copy[n] = '\0';
    
    char *cantidad_s = extract_field(body_copy, "cantidad");
    char *digitos_s = extract_field(body_copy, "digitos");
    int cantidad = cantidad_s ? atoi(cantidad_s) : 1;
    int digitos = digitos_s ? atoi(digitos_s) : 12;
    
    if (cantidad <= 0 || cantidad > 1000) {
        mg_http_reply(c, 400, "Content-Type: application/json\r\n",
            "{\"error\":\"cantidad debe estar entre 1 y 1000\"}\n");
        free(cantidad_s); free(digitos_s);
        return;
    }
    if (digitos < 2 || digitos > 20) {
        mg_http_reply(c, 400, "Content-Type: application/json\r\n",
            "{\"error\":\"digitos debe estar entre 2 y 20\"}\n");
        free(cantidad_s); free(digitos_s);
        return;
    }
    
    free(cantidad_s); free(digitos_s);

    char id[64];
    if (db_create_solicitud_and_enqueue(id, cantidad, digitos) != 0) {
        mg_http_reply(c, 500, "Content-Type: application/json\r\n",
            "{\"error\":\"db insert failed\"}\n");
        return;
    }
    char resp[128];
    snprintf(resp, sizeof(resp), "{\"id\":\"%s\"}\n", id);
    mg_http_reply(c, 200, "Content-Type: application/json\r\n", resp);
}

static void handle_status(struct mg_connection *c, struct mg_http_message *hm) {
    char path[128];
    snprintf(path, sizeof(path), "%.*s", (int)hm->uri.len, hm->uri.buf);
    const char *prefix = "/status/";
    if (strncmp(path, prefix, strlen(prefix)) != 0) {
        mg_http_reply(c, 400, "Content-Type: application/json\r\n",
            "{\"error\":\"missing id\"}\n");
        return;
    }
    
    const char *sid = path + strlen(prefix);
    if (!sid || !*sid) {
        mg_http_reply(c, 400, "Content-Type: application/json\r\n",
            "{\"error\":\"missing id\"}\n");
        return;
    }
    
    int cantidad, digitos, generados;
    int r = db_get_status(sid, &cantidad, &digitos, &generados);
    if (r == -2) {
        mg_http_reply(c, 404, "Content-Type: application/json\r\n",
            "{\"error\":\"not found\"}\n");
        return;
    }
    if (r != 0) {
        mg_http_reply(c, 500, "Content-Type: application/json\r\n",
            "{\"error\":\"db error\"}\n");
        return;
    }
    
    char resp[256];
    snprintf(resp, sizeof(resp),
        "{\"id\":\"%s\",\"cantidad\":%d,\"digitos\":%d,\"generados\":%d}\n",
        sid, cantidad, digitos, generados);
    mg_http_reply(c, 200, "Content-Type: application/json\r\n", resp);
}

static void handle_result(struct mg_connection *c, struct mg_http_message *hm) {
    char path[128];
    snprintf(path, sizeof(path), "%.*s", (int)hm->uri.len, hm->uri.buf);
    
    const char *prefix = "/result/";
    if (strncmp(path, prefix, strlen(prefix)) != 0) {
        mg_http_reply(c, 400, "Content-Type: application/json\r\n",
            "{\"error\":\"missing id\"}\n");
        return;
    }
    
    const char *sid = path + strlen(prefix);
    if (!sid || !*sid) {
        mg_http_reply(c, 400, "Content-Type: application/json\r\n",
            "{\"error\":\"missing id\"}\n");
        return;
    }
    
    int count;
    char **arr = db_get_results(sid, &count);
    if (count == -1) {
        mg_http_reply(c, 500, "Content-Type: application/json\r\n",
            "{\"error\":\"db error\"}\n");
        return;
    }
    
    size_t bufsz = 2048;
    char *out = malloc(bufsz);
    strcpy(out, "{\"id\":\"");
    strcat(out, sid);
    strcat(out, "\",\"primos\":[");
    for (int i=0;i<count;++i) {
        size_t need = strlen(out) + strlen(arr[i]) + 4;
        if (need > bufsz) { bufsz *= 2; out = realloc(out, bufsz); }
        strcat(out, "\""); strcat(out, arr[i]); strcat(out, "\"");
        if (i < count-1) strcat(out, ",");
    }
    strcat(out, "]}\n");
    mg_http_reply(c, 200, "Content-Type: application/json\r\n", out);
    free(out);
    db_free_results(arr, count);
}

static void event_handler(struct mg_connection *c, int ev, void *ev_data) {
    if (ev == MG_EV_HTTP_MSG) {
        struct mg_http_message *hm = (struct mg_http_message *)ev_data;
        
        if (mg_match(hm->uri, mg_str("/"), NULL)) {
            mg_http_reply(c, 200, "Content-Type: application/json\r\n", "{\"status\":\"ok\"}");
        } else if (mg_match(hm->uri, mg_str("/new"), NULL)) {
            if (mg_match(hm->method, mg_str("POST"), NULL)) {
                handle_new(c, hm);
            } else {
                mg_http_reply(c, 405, "", "");
            }
        } else if (mg_match(hm->uri, mg_str("/status/*"), NULL)) {
            if (mg_match(hm->method, mg_str("GET"), NULL)) {
                handle_status(c, hm);
            } else {
                mg_http_reply(c, 405, "", "");
            }
        } else if (mg_match(hm->uri, mg_str("/result/*"), NULL)) {
            if (mg_match(hm->method, mg_str("GET"), NULL)) {
                handle_result(c, hm);
            } else {
                mg_http_reply(c, 405, "", "");
            }
        } else {
            mg_http_reply(c, 404, "", "Not found\n");
        }
    }
}

static void sigint_handler(int signo) {
    (void)signo;
    keep_running = 0;
    printf("[api] Shutting down...\n");
}

static redisContext *redis_init(void) {
    const char *redis_host = getenv("REDIS_HOST");
    const char *redis_port_s = getenv("REDIS_PORT");
    
    if (!redis_host) redis_host = "localhost";
    if (!redis_port_s) redis_port_s = "6379";
    
    int redis_port = atoi(redis_port_s);
    
    redisContext *c = redisConnect(redis_host, redis_port);
    if (!c || c->err) {
        fprintf(stderr, "[api] Redis connection failed: %s\n", 
            c ? c->errstr : "Out of memory");
        if (c) redisFree(c);
        return NULL;
    }
    printf("[api] Connected to Redis: %s:%d\n", redis_host, redis_port);
    return c;
}

int main(int argc, char **argv) {
    (void)argc; (void)argv;
    const char *env = getenv("DATABASE_URL");
    if (!env) {
        fprintf(stderr, "[api] ERROR: Set DATABASE_URL env var\n");
        return 1;
    }
    db_url = env;
    if (db_init(db_url) != 0) {
        fprintf(stderr, "[api] ERROR: Failed to initialize database\n");
        return 1;
    }
    
    redis_ctx = redis_init();
    if (!redis_ctx) {
        fprintf(stderr, "[api] ERROR: Failed to initialize Redis\n");
        db_close();
        return 1;
    }
    
    db_set_redis(redis_ctx);

    signal(SIGINT, sigint_handler);
    signal(SIGTERM, sigint_handler);

    mg_mgr_init(&mgr);
    const char *port = getenv("PORT") ? getenv("PORT") : DEFAULT_PORT;
    char listen_addr[64];
    snprintf(listen_addr, sizeof(listen_addr), "http://0.0.0.0:%s", port);
    mg_http_listen(&mgr, listen_addr, event_handler, NULL);
    printf("[api] Listening on %s\n", listen_addr);

    while (keep_running) mg_mgr_poll(&mgr, 1000);
    
    mg_mgr_free(&mgr);
    if (redis_ctx) redisFree(redis_ctx);
    db_close();
    printf("[api] Shutdown complete\n");
    return 0;
}
