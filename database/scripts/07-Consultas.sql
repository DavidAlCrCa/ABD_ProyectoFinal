--consultas de gestión y consultas avanzadas
use GimnasioDB;
go

--consultas de gestión de socios y membresías
--a1.socios activos con su membresía vigente y tipo
select s.SocioID, s.Nombres, s.Apellidos, t.Nombre as tipo_membresia, m.FechaInicio, m.FechaFin
from Socios s
join Membresias m on m.SocioID = s.SocioID and m.Estado = 'Activa'
join TiposMembresia t on t.TipoMembresiaID = m.TipoMembresiaID
where s.Estado = 'Activo'
order by s.Apellidos, s.Nombres;

--a2 socios activos que no tienen una membresía vigente
select s.SocioID, s.Nombres, s.Apellidos, s.Correo, s.FechaRegistro
from Socios s
where s.Estado = 'Activo'
  and not exists (select 1 from Membresias m
                  where m.SocioID = s.SocioID and m.Estado = 'Activa')
order by s.FechaRegistro desc;

--a3 membresías contratadas e ingreso aplicado por tipo de membresía
select t.Nombre as tipo_membresia,
       count(m.MembresiaID) as total_membresias,
       isnull(sum(m.PrecioAplicado), 0) as total_precio_aplicado
from TiposMembresia t
left join Membresias m on m.TipoMembresiaID = t.TipoMembresiaID
group by t.Nombre
order by total_membresias desc;

--a4 socios con pagos pendientes y monto adeudado
select s.SocioID, s.Nombres, s.Apellidos,
       count(p.PagoID) as pagos_pendientes,
       sum(p.Monto) as monto_pendiente
from Pagos p
join Membresias m on m.MembresiaID = p.MembresiaID
join Socios s on s.SocioID = m.SocioID
where p.Estado = 'Pendiente'
group by s.SocioID, s.Nombres, s.Apellidos
order by monto_pendiente desc;


--b1 ocupación de cada clase (reservas vigentes: confirmadas o completadas, vs capacidad)
select c.ClaseID, c.Nombre, c.FechaHoraInicio, c.Sala, c.Capacidad,
       count(r.ReservacionID) as reservas_vigentes,
       c.Capacidad - count(r.ReservacionID) as cupos_disponibles,
       cast(100.0 * count(r.ReservacionID) / c.Capacidad as decimal(6,2)) as ocupacion_pct
from Clases c
left join Reservaciones r on r.ClaseID = c.ClaseID
                         and r.Estado in ('Confirmada', 'Completada')
group by c.ClaseID, c.Nombre, c.FechaHoraInicio, c.Sala, c.Capacidad
order by c.FechaHoraInicio;

--b2 clases dictadas por cada entrenador
select e.EntrenadorID, e.Nombres + ' ' + e.Apellidos as entrenador, e.Especialidad,
       count(c.ClaseID) as total_clases
from Entrenadores e
left join Clases c on c.EntrenadorID = e.EntrenadorID
group by e.EntrenadorID, e.Nombres, e.Apellidos, e.Especialidad
order by total_clases desc;

--b3 socios con más reservaciones canceladas
select top 20 s.SocioID, s.Nombres, s.Apellidos, count(*) as cancelaciones
from Reservaciones r
join Socios s on s.SocioID = r.SocioID
where r.Estado = 'Cancelada'
group by s.SocioID, s.Nombres, s.Apellidos
order by cancelaciones desc;
go


-- c1 top 3 de socios con más asistencias efectivas en cada tipo de clase
--     funciones ventana rank() y dense_rank() con partition by
--     (solo reservaciones vigentes: confirmadas o completadas)
with asistencias_socio as (
    select c.Nombre as clase, r.SocioID, count(*) as total_asistencias
    from Asistencias a
    join Reservaciones r on r.ReservacionID = a.ReservacionID
    join Clases c on c.ClaseID = r.ClaseID
    where a.EstadoAsistencia = N'Asistió'
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

--c2 ingresos mensuales (pagos pagados), acumulado y variación contra el mes anterior
--     funciones ventana: sum() over (acumulado) y lag()
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

--c4 días entre reservaciones consecutivas de cada socio
--     función ventana: lag() con partition by
select r.SocioID, r.ReservacionID, r.FechaReservacion,
       lag(r.FechaReservacion) over (partition by r.SocioID order by r.FechaReservacion) as reservacion_anterior,
       datediff(day, lag(r.FechaReservacion) over (partition by r.SocioID order by r.FechaReservacion),
       r.FechaReservacion) as dias_entre_reservaciones
from Reservaciones r
where r.Estado in ('Confirmada', 'Completada')
order by r.SocioID, r.FechaReservacion;
go