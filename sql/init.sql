CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS solicitudes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cantidad INT NOT NULL,
    digitos INT NOT NULL,
    generados INT DEFAULT 0,
    creado_en TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS resultados (
    solicitud_id UUID NOT NULL REFERENCES solicitudes(id) ON DELETE CASCADE,
    primo TEXT NOT NULL,
    PRIMARY KEY (solicitud_id, primo)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_primo_global ON resultados (primo);
