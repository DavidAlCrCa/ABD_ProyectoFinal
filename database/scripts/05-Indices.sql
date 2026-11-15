--índices para optimizar las consultas de 07_consultas.sql
use GimnasioDB;
go
-- c2: filtra por estado y rango de fecha, suma monto (índice cubriente)
drop index if exists ix_pagos_estado_fechapago on Pagos;
create nonclustered index ix_pagos_estado_fechapago
on Pagos (Estado, FechaPago) include (Monto);

-- a4 y join pagos -> membresias (llave foránea sin índice por defecto)
drop index if exists ix_pagos_membresiaid on Pagos;
create nonclustered index ix_pagos_membresiaid
on Pagos (MembresiaID) include (Estado, Monto, FechaPago);

-- c1, c3, b1: reservaciones por clase filtradas por estado
drop index if exists ix_reservaciones_claseid_estado on Reservaciones;
create nonclustered index ix_reservaciones_claseid_estado
on Reservaciones (ClaseID, Estado) include (SocioID);

-- c4, b3: reservaciones por socio ordenadas por fecha (evita sort en lag)
drop index if exists ix_reservaciones_socioid_fecha on Reservaciones;
create nonclustered index ix_reservaciones_socioid_fecha
on Reservaciones (SocioID, FechaReservacion) include (Estado, ClaseID);

-- c3. filtrar asistencias por estado y devolver ReservacionID (cubriente; el UQ existente solo cubre ReservacionID)
drop index if exists ix_asistencias_estado_reservacionid on Asistencias;
create nonclustered index ix_asistencias_estado_reservacionid
on Asistencias (EstadoAsistencia, ReservacionID);

-- c3, b2: clases por entrenador
drop index if exists ix_clases_entrenadorid on Clases;
create nonclustered index ix_clases_entrenadorid
on Clases (EntrenadorID) include (Nombre, FechaHoraInicio, Capacidad);

-- a1, a2: membresías por socio y estado
drop index if exists ix_membresias_socioid_estado on Membresias;
create nonclustered index ix_membresias_socioid_estado
on Membresias (SocioID, Estado) include (TipoMembresiaID, FechaInicio, FechaFin);
go

--revision de uso de los indices
select object_name(i.object_id) as tabla, i.name as indice,
       s.user_seeks, s.user_scans, s.user_lookups, s.user_updates
from sys.indexes i
left join sys.dm_db_index_usage_stats s
       on s.object_id = i.object_id and s.index_id = i.index_id and s.database_id = db_id()
where i.name like 'ix[_]%'
order by tabla, indice;

--revision de fragmentacion
select object_name(ps.object_id) as tabla, i.name as indice,
       ps.avg_fragmentation_in_percent, ps.page_count
from sys.dm_db_index_physical_stats(db_id(), null, null, null, 'limited') ps
join sys.indexes i on i.object_id = ps.object_id and i.index_id = ps.index_id
where i.name like 'ix[_]%';
go
