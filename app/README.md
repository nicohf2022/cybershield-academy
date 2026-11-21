# Aplicación mínima de CyberShield Academy

Aplicación web mínima desarrollada con Flask y PostgreSQL. Su propósito es comprobar el funcionamiento de la aplicación, la conexión con la base de datos y la persistencia de los registros antes de desplegar la solución en AWS.

## Arquitectura local

```text
Navegador
    |
    | http://localhost:8000
    v
Flask + Gunicorn
    |
    | db:5432
    v
PostgreSQL
    |
    v
Volumen Docker postgres_data
```

La aplicación y PostgreSQL se ejecutan en contenedores separados. Ambos se comunican mediante la red privada creada por Docker Compose.

PostgreSQL no publica su puerto en la computadora. Solamente la aplicación puede acceder a la base de datos mediante el nombre interno `db`.

## Requisitos

- Docker Desktop
- Docker Compose
- Git

Comprobar las instalaciones:

```bash
docker --version
docker compose version
```

Docker Desktop debe estar abierto antes de ejecutar los contenedores.

## Configuración

Desde la carpeta `app`, copiar el archivo de ejemplo:

```bash
cp .env.example .env
```

Editar `.env` y reemplazar la contraseña de ejemplo:

```dotenv
APP_PORT=8000
POSTGRES_DB=cybershield
POSTGRES_USER=cybershield_app
POSTGRES_PASSWORD=una-contraseña-local
```

El archivo `.env` contiene configuración privada y no debe subirse al repositorio.

## Validar la configuración

```bash
docker compose config --quiet
```

Si el archivo es válido, el comando termina sin mostrar errores.

## Construir la aplicación

```bash
docker compose build
```

Este comando crea la imagen de Flask a partir del `Dockerfile` e instala las dependencias definidas en `requirements.txt`.

## Iniciar los servicios

```bash
docker compose up -d
```

Docker Compose realiza las siguientes acciones:

1. Crea la red privada.
2. Crea el volumen persistente.
3. Inicia PostgreSQL.
4. Ejecuta `database/init.sql` si la base está vacía.
5. Espera a que PostgreSQL esté saludable.
6. Inicia Flask mediante Gunicorn.
7. Publica la aplicación en el puerto configurado.

Comprobar el estado:

```bash
docker compose ps
```

PostgreSQL debe figurar como `healthy` y la aplicación como `Up`.

## Abrir la aplicación

```bash
open http://localhost:8000
```

También se puede ingresar manualmente desde el navegador:

```text
http://localhost:8000
```

La página muestra registros consultados directamente desde PostgreSQL.

## Verificar el estado de salud

```bash
curl -i http://localhost:8000/health
```

La respuesta esperada es:

```text
HTTP/1.1 200 OK
```

```json
{"status":"ok"}
```

Esta verificación confirma que Flask está funcionando y puede consultar PostgreSQL.

## Consultar PostgreSQL

Abrir la consola de PostgreSQL:

```bash
docker compose exec db sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
```

Consultar los registros:

```sql
SELECT id, slug, title
FROM lessons
ORDER BY id;
```

Salir:

```text
\q
```

## Probar la persistencia

Ingresar a PostgreSQL:

```bash
docker compose exec db sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
```

Crear un registro de prueba:

```sql
INSERT INTO lessons (slug, title, description)
VALUES (
    'persistence-test',
    'Prueba de persistencia',
    'Este registro debe sobrevivir al reinicio.'
)
ON CONFLICT (slug) DO NOTHING;
```

Salir con:

```text
\q
```

Recrear los contenedores:

```bash
docker compose down
docker compose up -d
```

El registro debe continuar visible en `http://localhost:8000`. Esto demuestra que los datos permanecen almacenados en el volumen de Docker.

## Ver registros de ejecución

Aplicación:

```bash
docker compose logs -f app
```

PostgreSQL:

```bash
docker compose logs -f db
```

Presionar `Control + C` para dejar de observar los registros. Esto no detiene los contenedores.

## Detener el entorno

```bash
docker compose down
```

Este comando elimina los contenedores y la red, pero conserva los datos.

## Eliminar todos los datos locales

```bash
docker compose down -v
```

Advertencia: la opción `-v` elimina el volumen de PostgreSQL y todos sus registros. La próxima vez que se inicie el entorno, `database/init.sql` creará nuevamente la tabla y los datos iniciales.

## Archivos principales

```text
app/
├── .dockerignore
├── .env.example
├── Dockerfile
├── README.md
├── compose.yaml
├── requirements.txt
├── database/
│   └── init.sql
└── src/
    ├── app.py
    └── templates/
        └── index.html
```

- `compose.yaml`: coordina la aplicación, PostgreSQL, la red y el volumen.
- `Dockerfile`: define cómo se construye la imagen de Flask.
- `requirements.txt`: contiene las dependencias de Python.
- `database/init.sql`: crea la tabla y los registros iniciales.
- `src/app.py`: contiene las rutas y la conexión a PostgreSQL.
- `src/templates/index.html`: presenta los registros en el navegador.