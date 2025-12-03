#ifndef DB_H
#define DB_H

#include <libpq-fe.h>
#include <stdint.h>
#include <hiredis/hiredis.h>

int db_init(const char *conninfo);
void db_set_redis(redisContext *redis);
void db_close();

PGconn *db_open_connection(const char *conninfo);
void db_close_connection(PGconn *c);

int db_create_solicitud_and_enqueue(char *out_id, int cantidad, int digitos);

int db_fetch_job_for_worker(char *out_job_id, char *out_solicitud_id, int *out_cantidad, int *out_digitos);
int db_fetch_job_for_worker_conn(PGconn *c, char *out_job_id, char *out_solicitud_id, int *out_cantidad, int *out_digitos);

int db_mark_job_done(const char *job_id);
int db_mark_job_done_conn(PGconn *c, const char *job_id);

int db_insert_result(const char *solicitud_id, const char *primo);
int db_insert_result_conn(PGconn *c, const char *solicitud_id, const char *primo);

int db_inc_generado(const char *solicitud_id);
int db_inc_generado_conn(PGconn *c, const char *solicitud_id);


int db_get_status(const char *solicitud_id, int *cantidad, int *digitos, int *generados);
char ** db_get_results(const char *solicitud_id, int *count);
void db_free_results(char **arr, int count);

#endif
