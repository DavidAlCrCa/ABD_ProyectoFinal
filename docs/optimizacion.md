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

El código está en `database/scripts/04-Consultas.sql`.

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
Con los datos iniciales (3,000 reservaciones y 1,500 pagos) las tablas son muy pequeñas y la diferencia casi no se nota. Por eso se creó una base de pruebas (`gimnasio_pruebas`) con 50,000 pagos y 50,000 reservaciones adicionales (`database/testing/pruebas_rendimiento.sql`). Quedaron **51,500 pagos, 53,000 reservaciones y 53,000 asistencias**.

Se activó `SET STATISTICS IO, TIME ON` y el plan de ejecución real, se limpió la caché antes de cada medición y se ejecutó cada consulta sin índices y con índices.

| Consulta | Lecturas lógicas antes | Lecturas lógicas después | CPU antes (ms) | CPU después (ms) | Tiempo total antes → después (ms) | Cambio observado |
|---|---|---|---|---|---|---|
| C1 | 507 | 272 | 56 | 53 | 68 → 62 | Reservaciones 265 → 194 y Asistencias 222 → 59 lecturas |
| C2 | 398 | 122 | 47 | 41 | 52 → 52 | Pagos 398 → 122 lecturas |
| C3 | 666 | 910 | 41 | 26 | 48 → 31 | Reservaciones pasa de 265 lecturas (1 recorrido) a 510 lecturas (200 búsquedas por índice) |

Las lecturas lógicas son la suma de todas las tablas de cada consulta (en C3 incluye 281 lecturas de la tabla de trabajo, iguales antes y después). Los resultados que devuelven las tres consultas son los mismos antes y después de crear los índices.

**Evidencia:** capturas del plan de ejecución, de la pestaña Messages y de los resultados en `docs/evidencias/`.

## 6. Conclusiones
- Con los índices, C1 pasó de 507 a 272 lecturas lógicas (46% menos) y C2 de 398 a 122 (69% menos). En ambas se leen menos páginas porque los índices incluyen las columnas que cada consulta necesita.
- En C3 las lecturas de la tabla Reservaciones aumentaron (265 a 510). El optimizador cambió de recorrer la tabla una vez a hacer 200 búsquedas por índice, una por cada clase y cada estado de la condición `IN`. Aun así el CPU bajó de 41 a 26 ms y el tiempo total de 48 a 31 ms, así que menos lecturas no siempre significa menos tiempo.
- Las diferencias de CPU son de pocos milisegundos porque el volumen de prueba es moderado; por eso la métrica principal fue la de lecturas lógicas.
- Los índices tienen un costo: ocupan espacio y hacen más lentos los `INSERT`, `UPDATE` y `DELETE`. Por eso solo se crearon los necesarios para las consultas del proyecto.
