# Diccionario de Datos
## Sistema de Gestión de Gimnasio

### 1. Introducción

El presente diccionario de datos describe las tablas y atributos que conforman la base de datos del Sistema de Gestión de Gimnasio.

Para cada tabla se especifican los nombres de los campos, sus tipos de datos, restricciones y funciones dentro del sistema.

Las restricciones indicadas constituyen la propuesta de implementación que se aplicará posteriormente en SQL Server.

### 2. Tabla: Socios

Almacena la información de las personas inscritas en el gimnasio.

| Campo | Tipo SQL | Restricción | Descripción |
|---|---|---|---|
| SocioID | INT | PK, IDENTITY | Identificador único del socio. |
| Nombres | NVARCHAR(80) | NOT NULL | Nombres del socio. |
| Apellidos | NVARCHAR(80) | NOT NULL | Apellidos del socio. |
| Correo | VARCHAR(150) | NOT NULL, UNIQUE | Correo electrónico. |
| Telefono | VARCHAR(20) | NULL | Número telefónico. |
| FechaNacimiento | DATE | NULL | Fecha de nacimiento. |
| FechaRegistro | DATE | NOT NULL | Fecha de inscripción. |
| Estado | VARCHAR(15) | NOT NULL, CHECK | Activo o Inactivo. |

### 3. Tabla: Entrenadores

Almacena los datos de los entrenadores encargados de impartir las clases.

| Campo | Tipo SQL | Restricción | Descripción |
|---|---|---|---|
| EntrenadorID | INT | PK, IDENTITY | Identificador del entrenador. |
| Nombres | NVARCHAR(80) | NOT NULL | Nombres del entrenador. |
| Apellidos | NVARCHAR(80) | NOT NULL | Apellidos del entrenador. |
| Correo | VARCHAR(150) | NOT NULL, UNIQUE | Correo electrónico. |
| Telefono | VARCHAR(20) | NULL | Teléfono de contacto. |
| Especialidad | NVARCHAR(100) | NOT NULL | Área de especialización. |
| FechaContratacion | DATE | NOT NULL | Fecha de contratación. |
| Estado | VARCHAR(15) | NOT NULL, CHECK | Activo o Inactivo. |

### 4. Tabla: TiposMembresia

Contiene los planes de membresía que ofrece el gimnasio.

| Campo | Tipo SQL | Restricción | Descripción |
|---|---|---|---|
| TipoMembresiaID | INT | PK, IDENTITY | Identificador del plan. |
| Nombre | NVARCHAR(50) | NOT NULL, UNIQUE | Nombre de la membresía. |
| Descripcion | NVARCHAR(200) | NULL | Características del plan. |
| DuracionDias | INT | NOT NULL, CHECK (> 0) | Duración en días. |
| PrecioBase | DECIMAL(10,2) | NOT NULL, CHECK (>= 0) | Precio del plan. |
| Estado | VARCHAR(15) | NOT NULL, CHECK | Activo o Inactivo. |

### 5. Tabla: Membresias

Registra las membresías adquiridas por los socios.

| Campo | Tipo SQL | Restricción | Descripción |
|---|---|---|---|
| MembresiaID | INT | PK, IDENTITY | Identificador de la contratación. |
| SocioID | INT | FK, NOT NULL | Referencia a Socios. |
| TipoMembresiaID | INT | FK, NOT NULL | Referencia a TiposMembresia. |
| FechaInicio | DATE | NOT NULL | Inicio de la membresía. |
| FechaFin | DATE | NOT NULL, CHECK | Fecha fin posterior a inicio. |
| PrecioAplicado | DECIMAL(10,2) | NOT NULL, CHECK (>= 0) | Precio cobrado al socio. |
| Estado | VARCHAR(15) | NOT NULL, CHECK | Activa, Vencida o Cancelada. |

### 6. Tabla: Clases

Registra las sesiones programadas que ofrece el gimnasio.

| Campo | Tipo SQL | Restricción | Descripción |
|---|---|---|---|
| ClaseID | INT | PK, IDENTITY | Identificador de la sesión. |
| Nombre | NVARCHAR(80) | NOT NULL | Nombre de la clase. |
| Descripcion | NVARCHAR(200) | NULL | Descripción de la actividad. |
| EntrenadorID | INT | FK, NOT NULL | Entrenador asignado. |
| FechaHoraInicio | DATETIME2 | NOT NULL | Inicio de la sesión. |
| FechaHoraFin | DATETIME2 | NOT NULL, CHECK | Fin posterior al inicio. |
| Capacidad | INT | NOT NULL, CHECK (> 0) | Cupo máximo permitido. |
| Sala | NVARCHAR(50) | NOT NULL | Lugar donde se imparte. |
| Estado | VARCHAR(15) | NOT NULL, CHECK | Programada, Finalizada o Cancelada. |

### 7. Tabla: Reservaciones

Relaciona a los socios con las clases que desean reservar.

| Campo | Tipo SQL | Restricción | Descripción |
|---|---|---|---|
| ReservacionID | INT | PK, IDENTITY | Identificador de la reservación. |
| SocioID | INT | FK, NOT NULL | Socio que reserva. |
| ClaseID | INT | FK, NOT NULL | Clase reservada. |
| FechaReservacion | DATETIME2 | NOT NULL | Momento de la reserva. |
| Estado | VARCHAR(15) | NOT NULL, CHECK | Confirmada, Cancelada o Lista de espera. |

### 8. Tabla: Pagos

Registra los pagos asociados a las membresías contratadas.

| Campo | Tipo SQL | Restricción | Descripción |
|---|---|---|---|
| PagoID | INT | PK, IDENTITY | Identificador del pago. |
| MembresiaID | INT | FK, NOT NULL | Membresía correspondiente. |
| FechaPago | DATETIME2 | NOT NULL | Momento del pago. |
| Monto | DECIMAL(10,2) | NOT NULL, CHECK (> 0) | Cantidad pagada. |
| MetodoPago | VARCHAR(30) | NOT NULL, CHECK | Efectivo, Tarjeta o Transferencia. |
| Referencia | VARCHAR(100) | NULL | Referencia de la operación. |
| Estado | VARCHAR(15) | NOT NULL, CHECK | Pagado, Pendiente o Rechazado. |

### 9. Tabla: Asistencias

Registra la asistencia de los socios a las clases reservadas.

| Campo | Tipo SQL | Restricción | Descripción |
|---|---|---|---|
| AsistenciaID | INT | PK, IDENTITY | Identificador de asistencia. |
| ReservacionID | INT | FK, UNIQUE, NOT NULL | Reservación correspondiente. |
| FechaRegistro | DATETIME2 | NOT NULL | Momento del registro. |
| EstadoAsistencia | VARCHAR(15) | NOT NULL, CHECK | Asistió, Ausente o Justificada. |

La restricción UNIQUE de ReservacionID evita que una misma reservación tenga más de un registro de asistencia.

### 10. Relaciones entre tablas

| Tabla origen | Tabla destino | Clave foránea | Cardinalidad |
|---|---|---|---|
| Socios | Membresias | SocioID | 1:N |
| TiposMembresia | Membresias | TipoMembresiaID | 1:N |
| Entrenadores | Clases | EntrenadorID | 1:N |
| Socios | Reservaciones | SocioID | 1:N |
| Clases | Reservaciones | ClaseID | 1:N |
| Membresias | Pagos | MembresiaID | 1:N |
| Reservaciones | Asistencias | ReservacionID | 1:0..1 |

### 11. Reglas generales de integridad

La base de datos utilizará las siguientes restricciones:

- **PRIMARY KEY:** para identificar de manera única cada registro.
- **FOREIGN KEY:** para mantener la integridad referencial entre tablas.
- **NOT NULL:** para exigir información en campos obligatorios.
- **UNIQUE:** para evitar valores duplicados en campos seleccionados.
- **CHECK:** para validar estados, precios, duraciones, capacidades y fechas.
- **IDENTITY:** para generar automáticamente identificadores numéricos.

Estas restricciones se implementarán en los scripts SQL correspondientes a la creación de tablas y a la configuración de integridad.

### 12. Consideraciones de implementación

El modelo está diseñado para SQL Server 2025 Developer.

Los valores de las claves primarias serán enteros y se propone utilizar IDENTITY(1,1) para su generación automática, siempre que sea compatible con la estrategia de importación de datos.

Las columnas monetarias utilizarán DECIMAL(10,2) para almacenar importes con dos posiciones decimales.

Las columnas de nombres y descripciones utilizarán NVARCHAR, mientras que las fechas utilizarán DATE o DATETIME2 según sea necesario.

Las reglas de negocio que requieran consultar varias filas, como verificar que el número de reservaciones confirmadas no supere la capacidad de una clase, deberán implementarse mediante procedimientos almacenados u otra lógica transaccional apropiada.