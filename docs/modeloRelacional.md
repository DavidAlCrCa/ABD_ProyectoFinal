# Modelo Relacional – Sistema de Gestión de Gimnasio

## Descripción

La base de datos del gimnasio está compuesta por ocho tablas relacionadas entre sí. Su estructura permite almacenar información de socios, entrenadores, planes de membresía, membresías adquiridas, clases programadas, reservaciones, pagos y asistencias.

Cada tabla posee una clave primaria (PK) que identifica sus registros. Las claves foráneas (FK) permiten establecer relaciones y mantener la integridad referencial.

## Tablas del modelo relacional

1. Socios

Socios(SocioID**, Nombres, Apellidos, Correo, Telefono, FechaNacimiento, FechaRegistro, Estado)

PK: SocioID

2. Entrenadores

Entrenadores(EntrenadorID**, Nombres, Apellidos, Correo, Telefono, Especialidad, FechaContratacion, Estado)

PK: EntrenadorID

3. TiposMembresia

TiposMembresia(TipoMembresiaID**, Nombre, Descripcion, DuracionDias, PrecioBase, Estado)

PK: TipoMembresiaID

4. Membresias

Membresias(MembresiaID**, SocioID, TipoMembresiaID, FechaInicio, FechaFin, PrecioAplicado, Estado)

PK: MembresiaID

FK: SocioID → Socios(SocioID)

FK: TipoMembresiaID → TiposMembresia(TipoMembresiaID)

5. Clases

Clases(ClaseID**, Nombre, Descripcion, EntrenadorID, FechaHoraInicio, FechaHoraFin, Capacidad, Sala, Estado)

PK: ClaseID

FK: EntrenadorID → Entrenadores(EntrenadorID)

6. Reservaciones

Reservaciones(ReservacionID**, SocioID, ClaseID, FechaReservacion, Estado)

PK: ReservacionID

FK: SocioID → Socios(SocioID)

FK: ClaseID → Clases(ClaseID)

7. Pagos

Pagos(PagoID**, MembresiaID, FechaPago, Monto, MetodoPago, Referencia, Estado)

PK: PagoID

FK: MembresiaID → Membresias(MembresiaID)

8. Asistencias

Asistencias(AsistenciaID**, ReservacionID, FechaRegistro, EstadoAsistencia)

PK: AsistenciaID

FK: ReservacionID → Reservaciones(ReservacionID)

UNIQUE: ReservacionID, para permitir como máximo una asistencia por reservación.

## Relaciones y cardinalidades

| Tabla principal | Tabla relacionada | Cardinalidad |
|---|---|---|
| Socios | Membresias | 1:N |
| TiposMembresia | Membresias | 1:N |
| Entrenadores | Clases | 1:N |
| Socios | Reservaciones | 1:N |
| Clases | Reservaciones | 1:N |
| Membresias | Pagos | 1:N |
| Reservaciones | Asistencias | 1:0..1 |

## Consideraciones del diseño

El modelo separa los tipos de membresía de las membresías contratadas. Esto permite almacenar los planes ofrecidos por el gimnasio sin repetir sus características en cada contratación.

La tabla Reservaciones relaciona a los socios con las clases programadas. La tabla Asistencias registra si un socio asistió, estuvo ausente o justificó su ausencia.

Cada registro de la tabla Clases representa una sesión programada, con su fecha, horario, entrenador y capacidad.

Las relaciones se implementarán posteriormente mediante claves foráneas y restricciones de integridad en SQL Server.