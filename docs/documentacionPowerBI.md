# Documentación técnica – Integración con Power BI
---

## 1. Introducción

Como parte del desarrollo del Sistema de Reservas de Gimnasio, se implementó un dashboard interactivo utilizando Microsoft Power BI, conectado a la base de datos `GimnasioDB` desarrollada en SQL Server.

Esta implementación tiene como finalidad facilitar la interpretación de la información almacenada en la base de datos mediante indicadores y representaciones gráficas que permitan analizar el comportamiento financiero del gimnasio.

El dashboard desarrollado presenta información relacionada con los ingresos obtenidos, la cantidad de pagos realizados, los métodos de pago utilizados y la distribución de ingresos según los tipos de membresía.

Para su implementación se utilizaron consultas SQL con operaciones de agrupación y agregación, así como medidas calculadas mediante el lenguaje DAX (Data Analysis Expressions).

## 2. Objetivos

### Objetivo general

Implementar un dashboard en Microsoft Power BI conectado a SQL Server que permita visualizar y analizar información financiera del Sistema de Reservas de Gimnasio.

### Objetivos específicos

- Establecer una conexión entre Power BI y SQL Server mediante DirectQuery.
- Implementar una consulta SQL que permita obtener información consolidada de pagos y membresías.
- Crear medidas DAX para calcular indicadores financieros.
- Desarrollar visualizaciones que faciliten la interpretación de los ingresos del gimnasio.
- Presentar información que pueda utilizarse como apoyo para la toma de decisiones administrativas.

## 3. Herramientas utilizadas

**Microsoft SQL Server 2025:** sistema gestor de bases de datos utilizado para almacenar y administrar la información del gimnasio.

**Microsoft Power BI Desktop:** herramienta utilizada para la creación del dashboard y la representación gráfica de los datos.

**SQL (Structured Query Language):** lenguaje empleado para consultar, relacionar y agrupar los registros almacenados en la base de datos.

**DAX (Data Analysis Expressions):** lenguaje utilizado en Power BI para crear medidas e indicadores calculados.

**GitHub:** plataforma utilizada para almacenar y documentar los archivos correspondientes al proyecto.

## 4. Integración de Power BI con SQL Server

### 4.1. Configuración de la conexión

Para establecer la comunicación entre Power BI y SQL Server, se utilizó el conector nativo de bases de datos SQL Server disponible en Power BI Desktop.

La conexión se configuró utilizando los siguientes parámetros:

| Parámetro | Configuración |
|---|---|
| Servidor | `localhost,1434` |
| Base de datos | `GimnasioDB` |
| Modo de conectividad | DirectQuery |
| Origen de datos | Consulta SQL personalizada |

Se seleccionó el modo **DirectQuery**, que permite a Power BI consultar directamente la base de datos SQL Server cuando se requiere recuperar información para las visualizaciones.

A diferencia del modo Importar, DirectQuery no necesita almacenar una copia completa de los registros consultados dentro del modelo de Power BI.

### 4.2. Tablas utilizadas

Para la elaboración del dashboard financiero se utilizaron tres tablas principales:

**Pagos:** contiene la información de las transacciones realizadas, incluyendo identificador del pago, fecha, monto, método de pago y estado.

**Membresias:** almacena la información de las membresías contratadas por los socios, incluyendo su identificador, tipo de membresía y precio aplicado.

**TiposMembresia:** contiene la clasificación de los planes disponibles en el gimnasio, como Básica, Premium y Anual.

Estas tablas se relacionaron mediante sus identificadores correspondientes:

- `Pagos.MembresiaID = Membresias.MembresiaID`
- `Membresias.TipoMembresiaID = TiposMembresia.TipoMembresiaID`

## 5. Implementación de la consulta SQL

Para obtener la información necesaria se desarrolló una consulta SQL que combina las tres tablas mencionadas.

La consulta utiliza operaciones `INNER JOIN`, funciones de agregación y agrupaciones mediante `GROUP BY`.

```sql
SELECT
    YEAR(p.FechaPago) AS Anio,
    MONTH(p.FechaPago) AS NumeroMes,
    CASE MONTH(p.FechaPago)
        WHEN 1 THEN 'Enero'
        WHEN 2 THEN 'Febrero'
        WHEN 3 THEN 'Marzo'
        WHEN 4 THEN 'Abril'
        WHEN 5 THEN 'Mayo'
        WHEN 6 THEN 'Junio'
        WHEN 7 THEN 'Julio'
        WHEN 8 THEN 'Agosto'
        WHEN 9 THEN 'Septiembre'
        WHEN 10 THEN 'Octubre'
        WHEN 11 THEN 'Noviembre'
        WHEN 12 THEN 'Diciembre'
    END AS Mes,
    tm.Nombre AS TipoMembresia,
    p.MetodoPago,
    COUNT(p.PagoID) AS CantidadPagos,
    SUM(p.Monto) AS IngresosTotales,
    AVG(p.Monto) AS PagoPromedio
FROM dbo.Pagos AS p
INNER JOIN dbo.Membresias AS m
    ON p.MembresiaID = m.MembresiaID
INNER JOIN dbo.TiposMembresia AS tm
    ON m.TipoMembresiaID = tm.TipoMembresiaID
WHERE p.Estado = 'Pagado'
GROUP BY
    YEAR(p.FechaPago),
    MONTH(p.FechaPago),
    tm.Nombre,
    p.MetodoPago
```

### 5.1. Explicación de la consulta

La consulta realiza las siguientes operaciones:

1. **Relación de tablas:** utiliza `INNER JOIN` para asociar cada pago con su membresía y el tipo de plan contratado.
2. **Filtrado de registros:** mediante `WHERE`, selecciona únicamente los pagos cuyo estado sea `Pagado`.
3. **Agrupación de información:** utiliza `GROUP BY` para organizar los resultados por año, mes, tipo de membresía y método de pago.
4. **Cálculo de indicadores:** utiliza `COUNT`, `SUM` y `AVG` para calcular la cantidad de pagos, ingresos totales y promedio de pago.
5. **Transformación de fechas:** utiliza `YEAR`, `MONTH` y `CASE` para identificar los períodos y mostrar los nombres de los meses en español.

### 5.2. Consideraciones de rendimiento

La consulta selecciona únicamente las columnas necesarias para el análisis financiero y realiza operaciones de agregación directamente en SQL Server.

Esto permite obtener un conjunto de datos resumido, evitando recuperar todas las columnas y registros individuales de pagos.

Sin embargo, para demostrar una mejora de rendimiento es necesario realizar pruebas adicionales, como analizar el plan de ejecución de la consulta y comparar los tiempos de respuesta antes y después de aplicar índices.

## 6. Implementación de medidas DAX

Además de los cálculos realizados mediante SQL, se implementaron medidas DAX para generar indicadores dentro del dashboard.

### 6.1. Total de ingresos

```dax
Total Ingresos =
SUM(IngresosMensuales[IngresosTotales])
```

Esta medida calcula la suma de los ingresos obtenidos a partir de los pagos registrados.

### 6.2. Total de pagos

```dax
Total Pagos =
SUM(IngresosMensuales[CantidadPagos])
```

Permite determinar la cantidad total de pagos realizados y registrados con el estado `Pagado`.

### 6.3. Pago promedio general

```dax
Pago Promedio General =
DIVIDE(
    [Total Ingresos],
    [Total Pagos],
    0
)
```

Esta medida calcula el valor promedio de las transacciones realizadas, dividiendo los ingresos totales entre la cantidad de pagos.

Se utiliza la función `DIVIDE` para evitar errores cuando el denominador sea cero.

### 6.4. Mes con mayores ingresos

Para identificar automáticamente el mes que registra la mayor cantidad de ingresos, se implementó una medida utilizando funciones de agrupación y ordenamiento.

```dax
Mes con Mas Ingresos =
VAR TablaMeses =
    SUMMARIZE(
        IngresosMensuales,
        IngresosMensuales[Mes],
        IngresosMensuales[NumeroMes],
        "TotalMes",
        SUM(IngresosMensuales[IngresosTotales])
    )

VAR MejorMes =
    TOPN(
        1,
        TablaMeses,
        [TotalMes], DESC,
        IngresosMensuales[NumeroMes], ASC
    )

RETURN
    CONCATENATEX(
        MejorMes,
        IngresosMensuales[Mes],
        ", "
    )
```

Esta medida permite identificar el mes de mayor facturación según los registros y filtros disponibles en el dashboard.

## 7. Visualizaciones implementadas

El dashboard financiero está compuesto por cuatro indicadores principales y tres gráficos.

### 7.1. Indicadores financieros

Se implementaron cuatro tarjetas que presentan información resumida:

| Indicador | Resultado observado |
|---|---|
| Total de ingresos | $41,710.00 |
| Total de pagos | 729 |
| Pago promedio general | $57.22 |
| Mes con mayores ingresos | Octubre |

Estos valores corresponden a los resultados observados durante las pruebas del dashboard y pueden variar cuando se actualicen los registros de la base de datos.

### 7.2. Gráfico de pagos por método de pago

Se implementó un gráfico de columnas que representa la cantidad de pagos realizados mediante los diferentes métodos disponibles.

Las categorías utilizadas son:

- Efectivo.
- Tarjeta.
- Transferencia.

Este gráfico permite identificar cuáles son los métodos de pago más utilizados por los socios.

### 7.3. Gráfico de ingresos por tipo de membresía

Se desarrolló un gráfico de dona que representa la distribución de los ingresos entre los distintos tipos de membresía.

Los resultados observados fueron:

| Tipo de membresía | Ingresos | Porcentaje aproximado |
|---|---:|---:|
| Anual | $25,560 | 61.28 % |
| Premium | $10,290 | 24.67 % |
| Básica | $5,860 | 14.05 % |

Esta visualización permite identificar qué tipo de membresía genera la mayor proporción de ingresos.

### 7.4. Gráfico de ingresos mensuales

Se implementó un gráfico de columnas que presenta los ingresos del gimnasio desde enero hasta diciembre.

La información se obtiene a partir de la fecha de pago y la suma de los montos registrados.

El gráfico permite identificar variaciones en los ingresos durante el año y reconocer los períodos de mayor actividad financiera.

En los resultados observados, octubre fue el mes que registró los mayores ingresos.

## 8. Evidencias de implementación

Para documentar el funcionamiento del dashboard se deben incorporar capturas de pantalla que muestren:

**Evidencia 1.** Conexión de Power BI con SQL Server mediante DirectQuery.

**Evidencia 2.** Consulta SQL utilizada para obtener la información financiera.

**Evidencia 3.** Medidas DAX implementadas en Power BI.

**Evidencia 4.** Dashboard financiero completo con los cuatro indicadores y tres gráficos.

Las capturas deben permitir verificar la conexión, los cálculos realizados y los resultados obtenidos.

## 9. Resultados obtenidos

La implementación permitió integrar la información financiera almacenada en SQL Server con Microsoft Power BI.

Mediante la consulta SQL desarrollada se obtuvo información consolidada de pagos y membresías, mientras que las medidas DAX permitieron calcular indicadores adicionales para facilitar el análisis.

El dashboard desarrollado permite visualizar los ingresos totales, la cantidad de pagos, el promedio por transacción, el mes de mayor facturación y la distribución de ingresos por tipo de membresía.

Asimismo, las visualizaciones permiten comparar el comportamiento de los ingresos a lo largo del año y analizar la utilización de los diferentes métodos de pago.

## 10. Conclusiones

La integración de Power BI con SQL Server permitió transformar los registros financieros del Sistema de Reservas de Gimnasio en información visual organizada y comprensible.

El uso de DirectQuery facilitó la conexión con la base de datos, mientras que las consultas SQL permitieron relacionar y agrupar los registros necesarios para el análisis.

Por otra parte, la implementación de medidas DAX permitió generar indicadores adicionales a partir de la información obtenida, demostrando la utilidad de combinar consultas SQL con herramientas de inteligencia de negocios.

Finalmente, el dashboard financiero constituye una herramienta de apoyo para analizar los ingresos del gimnasio y reconocer tendencias relevantes para su administración.
