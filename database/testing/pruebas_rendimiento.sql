--comparacion del antes y despues de los indices
use master;
go
drop database if exists gimnasio_pruebas;
create database gimnasio_pruebas;
go
use gimnasio_pruebas;
go

--tablas y copia de datos
create table Socios (SocioID int not null primary key, Nombres nvarchar(80), Apellidos nvarchar(80), Correo varchar(150), Telefono varchar(20), FechaNacimiento date, FechaRegistro date, Estado varchar(15));
create table Entrenadores (EntrenadorID int not null primary key, Nombres nvarchar(80), Apellidos nvarchar(80), Correo varchar(150), Telefono varchar(20), Especialidad nvarchar(100), FechaContratacion date, Estado varchar(15));
create table TiposMembresia (TipoMembresiaID int not null primary key, Nombre nvarchar(50), Descripcion nvarchar(200), DuracionDias int, PrecioBase decimal(10,2), Estado varchar(15));
create table Membresias (MembresiaID int not null primary key, SocioID int, TipoMembresiaID int, FechaInicio date, FechaFin date, PrecioAplicado decimal(10,2), Estado varchar(15));
create table Clases (ClaseID int not null primary key, Nombre nvarchar(80), Descripcion nvarchar(200), EntrenadorID int, FechaHoraInicio datetime2, FechaHoraFin datetime2, Capacidad int, Sala nvarchar(50), Estado varchar(15));
create table Reservaciones (ReservacionID int not null primary key, SocioID int, ClaseID int, FechaReservacion datetime2, Estado varchar(15));
create table Pagos (PagoID int not null primary key, MembresiaID int, FechaPago datetime2, Monto decimal(10,2), MetodoPago varchar(30), Referencia varchar(100), Estado varchar(15));
create table Asistencias (AsistenciaID int not null primary key, ReservacionID int, FechaRegistro datetime2, EstadoAsistencia varchar(15));
go

insert into Socios (SocioID, Nombres, Apellidos, Correo, Telefono, FechaNacimiento, FechaRegistro, Estado)
select SocioID, Nombres, Apellidos, Correo, Telefono, FechaNacimiento, FechaRegistro, Estado from GimnasioDB.dbo.Socios;
insert into Entrenadores (EntrenadorID, Nombres, Apellidos, Correo, Telefono, Especialidad, FechaContratacion, Estado)
select EntrenadorID, Nombres, Apellidos, Correo, Telefono, Especialidad, FechaContratacion, Estado from GimnasioDB.dbo.Entrenadores;
insert into TiposMembresia (TipoMembresiaID, Nombre, Descripcion, DuracionDias, PrecioBase, Estado)
select TipoMembresiaID, Nombre, Descripcion, DuracionDias, PrecioBase, Estado from GimnasioDB.dbo.TiposMembresia;
insert into Membresias (MembresiaID, SocioID, TipoMembresiaID, FechaInicio, FechaFin, PrecioAplicado, Estado)
select MembresiaID, SocioID, TipoMembresiaID, FechaInicio, FechaFin, PrecioAplicado, Estado from GimnasioDB.dbo.Membresias;
insert into Clases (ClaseID, Nombre, Descripcion, EntrenadorID, FechaHoraInicio, FechaHoraFin, Capacidad, Sala, Estado)
select ClaseID, Nombre, Descripcion, EntrenadorID, FechaHoraInicio, FechaHoraFin, Capacidad, Sala, Estado from GimnasioDB.dbo.Clases;
insert into Reservaciones (ReservacionID, SocioID, ClaseID, FechaReservacion, Estado)
select ReservacionID, SocioID, ClaseID, FechaReservacion, Estado from GimnasioDB.dbo.Reservaciones;
insert into Pagos (PagoID, MembresiaID, FechaPago, Monto, MetodoPago, Referencia, Estado)
select PagoID, MembresiaID, FechaPago, Monto, MetodoPago, Referencia, Estado from GimnasioDB.dbo.Pagos;
insert into Asistencias (AsistenciaID, ReservacionID, FechaRegistro, EstadoAsistencia)
select AsistenciaID, ReservacionID, FechaRegistro, EstadoAsistencia from GimnasioDB.dbo.Asistencias;
go

--agregar volumen
-- volumen: +300,000 pagos  +300,000 reservaciones y asistencias
set nocount on;
declare @n int = 50000;

;with numeros as (
    select top (@n) row_number() over (order by (select null)) as n
    from sys.all_objects a cross join sys.all_objects b
)
insert into Pagos (PagoID, MembresiaID, FechaPago, Monto, MetodoPago, Referencia, Estado)
select 1500 + n,
       1 + abs(checksum(newid())) % 1000,
       dateadd(hour, -(abs(checksum(newid())) % 21600), '2026-06-01'),
       choose(1 + abs(checksum(newid())) % 3, 20, 35, 180),
       choose(1 + abs(checksum(newid())) % 3, 'Efectivo', 'Tarjeta', 'Transferencia'),
       'REF-' + cast(1500 + n as varchar(10)),
       choose(1 + abs(checksum(newid())) % 2, 'Pagado', 'Pendiente')
from numeros;

;with numeros as (
    select top (@n) row_number() over (order by (select null)) as n
    from sys.all_objects a cross join sys.all_objects b
)
insert into Reservaciones (ReservacionID, SocioID, ClaseID, FechaReservacion, Estado)
select 3000 + n,
       1 + abs(checksum(newid())) % 1000,
       1 + abs(checksum(newid())) % 100,
       dateadd(hour, -(abs(checksum(newid())) % 21600), '2026-12-31'),
       choose(1 + abs(checksum(newid())) % 3, 'Confirmada', 'Lista de espera', 'Cancelada')
from numeros;

insert into Asistencias (AsistenciaID, ReservacionID, FechaRegistro, EstadoAsistencia)
select ReservacionID, ReservacionID, dateadd(day, 2, FechaReservacion),
       choose(1 + abs(checksum(newid())) % 3, 'Asistió', 'Ausente', 'Justificada')
from Reservaciones
where ReservacionID > 3000;

select (select count(*) from Pagos) as Pagos,
       (select count(*) from Reservaciones) as Reservaciones,
       (select count(*) from Asistencias) as Asistencias;
go

-- medición antes (sin índices no clustered)
checkpoint;
dbcc dropcleanbuffers;
set statistics io on;
set statistics time on;
-- activar "incluir plan de ejecución real" (ctrl+m) antes de ejecutar

-- c1 top 3 de socios con más asistencias efectivas en cada tipo de clase
with asistencias_socio as (
    select c.Nombre as clase, r.SocioID, count(*) as total_asistencias
    from Asistencias a
    join Reservaciones r on r.ReservacionID = a.ReservacionID
    join Clases c on c.ClaseID = r.ClaseID
    where a.EstadoAsistencia = 'Asistió'
      and r.Estado in ('Confirmada', 'Completada')
    group by c.Nombre, r.SocioID
),
ranking as (
    select clase, SocioID, total_asistencias,
           rank()       over (partition by clase order by total_asistencias desc) as posicion,
           dense_rank() over (partition by clase order by total_asistencias desc) as posicion_densa
    from asistencias_socio
)
select rk.clase, s.Nombres + ' ' + s.Apellidos as socio,
       rk.total_asistencias, rk.posicion, rk.posicion_densa
from ranking rk
join Socios s on s.SocioID = rk.SocioID
where rk.posicion_densa <= 3
order by rk.clase, rk.posicion, socio;

-- c2 ingresos mensuales (pagos pagados), acumulado y variación contra el mes anterior
with ingresos_mes as (
    select datefromparts(year(FechaPago), month(FechaPago), 1) as mes,
           sum(Monto) as ingreso,
           count(*) as total_pagos
    from Pagos
    where Estado = 'Pagado'
    group by datefromparts(year(FechaPago), month(FechaPago), 1)
)
select mes, total_pagos, ingreso,
       sum(ingreso) over (order by mes rows unbounded preceding) as ingreso_acumulado,
       lag(ingreso) over (order by mes) as ingreso_mes_anterior,
       ingreso - lag(ingreso) over (order by mes) as variacion,
       cast(100.0 * (ingreso - lag(ingreso) over (order by mes))
            / nullif(lag(ingreso) over (order by mes), 0) as decimal(8,2)) as variacion_pct
from ingresos_mes
order by mes;

-- c3 top 3 clases con más reservas de cada entrenador
with reservas_clase as (
    select c.ClaseID, c.Nombre as clase, c.EntrenadorID, c.FechaHoraInicio,
           count(r.ReservacionID) as total_reservas
    from Clases c
    join Reservaciones r on r.ClaseID = c.ClaseID
    where r.Estado in ('Confirmada', 'Completada')
    group by c.ClaseID, c.Nombre, c.EntrenadorID, c.FechaHoraInicio
),
ordenadas as (
    select rc.*,
           row_number() over (partition by rc.EntrenadorID
                              order by rc.total_reservas desc, rc.ClaseID) as rn,
           sum(rc.total_reservas) over (partition by rc.EntrenadorID) as total_entrenador
    from reservas_clase rc
)
select e.Nombres + ' ' + e.Apellidos as entrenador,
       o.clase, o.FechaHoraInicio, o.total_reservas, o.rn as posicion,
       cast(100.0 * o.total_reservas / o.total_entrenador as decimal(5,2)) as pct_del_entrenador
from ordenadas o
join Entrenadores e on e.EntrenadorID = o.EntrenadorID
where o.rn <= 3
order by entrenador, posicion;

set statistics io off;
set statistics time off;
go

-- crear índices 

-- c2 filtra por estado y rango de fecha, suma monto (índice cubriente)
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

-- c1: filtrar asistencias por estado y devolver ReservacionID (cubriente; el UQ existente solo cubre ReservacionID)
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

--medición después 

--después: guardar lecturas lógicas, tiempos y plan 
checkpoint;
dbcc dropcleanbuffers;
set statistics io on;
set statistics time on;
-- activar "incluir plan de ejecución real" (ctrl+m) antes de ejecutar

-- c1 top 3 de socios con más asistencias efectivas en cada tipo de clase
with asistencias_socio as (
    select c.Nombre as clase, r.SocioID, count(*) as total_asistencias
    from Asistencias a
    join Reservaciones r on r.ReservacionID = a.ReservacionID
    join Clases c on c.ClaseID = r.ClaseID
    where a.EstadoAsistencia = 'Asistió'
      and r.Estado in ('Confirmada', 'Completada')
    group by c.Nombre, r.SocioID
),
ranking as (
    select clase, SocioID, total_asistencias,
           rank()       over (partition by clase order by total_asistencias desc) as posicion,
           dense_rank() over (partition by clase order by total_asistencias desc) as posicion_densa
    from asistencias_socio
)
select rk.clase, s.Nombres + ' ' + s.Apellidos as socio,
       rk.total_asistencias, rk.posicion, rk.posicion_densa
from ranking rk
join Socios s on s.SocioID = rk.SocioID
where rk.posicion_densa <= 3
order by rk.clase, rk.posicion, socio;

-- c2 ingresos mensuales (pagos pagados), acumulado y variación contra el mes anterior
with ingresos_mes as (
    select datefromparts(year(FechaPago), month(FechaPago), 1) as mes,
           sum(Monto) as ingreso,
           count(*) as total_pagos
    from Pagos
    where Estado = 'Pagado'
    group by datefromparts(year(FechaPago), month(FechaPago), 1)
)
select mes, total_pagos, ingreso,
       sum(ingreso) over (order by mes rows unbounded preceding) as ingreso_acumulado,
       lag(ingreso) over (order by mes) as ingreso_mes_anterior,
       ingreso - lag(ingreso) over (order by mes) as variacion,
       cast(100.0 * (ingreso - lag(ingreso) over (order by mes))
            / nullif(lag(ingreso) over (order by mes), 0) as decimal(8,2)) as variacion_pct
from ingresos_mes
order by mes;

-- c3 top 3 clases con más reservas de cada entrenador
--     funciones ventana: row_number() con partition by y sum() over (partition by)
with reservas_clase as (
    select c.ClaseID, c.Nombre as clase, c.EntrenadorID, c.FechaHoraInicio,
           count(r.ReservacionID) as total_reservas
    from Clases c
    join Reservaciones r on r.ClaseID = c.ClaseID
    where r.Estado in ('Confirmada', 'Completada')
    group by c.ClaseID, c.Nombre, c.EntrenadorID, c.FechaHoraInicio
),
ordenadas as (
    select rc.*,
           row_number() over (partition by rc.EntrenadorID
                              order by rc.total_reservas desc, rc.ClaseID) as rn,
           sum(rc.total_reservas) over (partition by rc.EntrenadorID) as total_entrenador
    from reservas_clase rc
)
select e.Nombres + ' ' + e.Apellidos as entrenador,
       o.clase, o.FechaHoraInicio, o.total_reservas, o.rn as posicion,
       cast(100.0 * o.total_reservas / o.total_entrenador as decimal(5,2)) as pct_del_entrenador
from ordenadas o
join Entrenadores e on e.EntrenadorID = o.EntrenadorID
where o.rn <= 3
order by entrenador, posicion;

set statistics io off;
set statistics time off;
go
