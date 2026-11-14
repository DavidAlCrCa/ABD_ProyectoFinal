# Optimización y consultas avanzadas

## 1. Objetivo
Diseñar consultas que respondan preguntas reales del gimnasio (ingresos, ocupación de clases, asistencia de socios), usar funciones ventana y reducir su costo con índices adecuados, comparando el rendimiento antes y después.

## 2. Tablas utilizadas
`Socios`, `Entrenadores`, `TiposMembresia`, `Membresias`, `Clases`, `Reservaciones`, `Pagos`, `Asistencias`.

## 3. Consultas avanzadas (funciones ventana)

| Consulta | Pregunta de negocio | Funciones ventana |
|---|---|---|
| C1 | ¿Qué socios asisten más a cada tipo de clase (top 3)? | rank, dense_rank, partition by |
| C2 | ¿Cómo evolucionan los ingresos mes a mes? | sum over (acumulado), lag |
| C3 | ¿Cuáles son las 3 clases más reservadas de cada entrenador? | row_number, sum over partition by |
| C4 (extra) | ¿Cada cuántos días reserva un socio? | lag, partition by |

El código está en `database/scripts/07_consultas.sql`.

## 4. Índices creados

| Índice | Tabla | Columnas clave | INCLUDE | Consulta beneficiada |
|---|---|---|---|---|
| ix_pagos_estado_fechapago | Pagos | Estado, FechaPago | Monto | C2 |
| ix_pagos_membresiaid | Pagos | MembresiaID | Estado, Monto, FechaPago | A4 |
| ix_reservaciones_claseid_estado | Reservaciones | ClaseID, Estado | SocioID | B1, C1, C3 |
| ix_reservaciones_socioid_fecha | Reservaciones | SocioID, FechaReservacion | Estado, ClaseID | B3, C4 |
| ix_asistencias_estado_reservacionid | Asistencias | EstadoAsistencia, ReservacionID | – | C1 |
| ix_clases_entrenadorid | Clases | EntrenadorID | Nombre, FechaHoraInicio, Capacidad | B2, C3 |
| ix_membresias_socioid_estado | Membresias | SocioID, Estado | TipoMembresiaID, FechaInicio, FechaFin | A1, A2 |

## 5. Pruebas de rendimiento
Con los datos iniciales (3,000 reservaciones y 1,500 pagos) las tablas son muy pequeñas y la diferencia casi no se nota. Por eso se creó una base de pruebas (`gimnasio_pruebas`) con ~300,000 pagos y ~300,000 reservaciones adicionales (`database/scripts/pruebas_rendimiento.sql`). Se activó `SET STATISTICS IO, TIME ON` y el plan de ejecución real, y se ejecutó cada consulta sin índices y con índices.

| Consulta | Lecturas lógicas antes | Lecturas lógicas después | CPU antes (ms) | CPU después (ms) | Cambio en el plan |
|---|---|---|---|---|---|
| C1 | _completar_ | _completar_ | _completar_ | _completar_ | _completar_ |
| C2 | _completar_ | _completar_ | _completar_ | _completar_ | _completar_ |
| C3 | _completar_ | _completar_ | _completar_ | _completar_ | _completar_ |

Evidencia: capturas en `docs/evidencias/` (plan antes, plan después, salida de STATISTICS IO).

