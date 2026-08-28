# Sistema de Inventario — Guía de instalación

## Nivel: Empresarial
Este proyecto incluye: autenticación con permisos por rol, manejo
global de errores, logs, Docker (para correr igual en cualquier
servidor), y tests automáticos que confirman que las reglas críticas
del negocio (nunca stock negativo, login obligatorio) funcionan.

## Estructura del proyecto
```
inventario_proyecto/
├── docker-compose.yml      <- Levanta TODO con un comando
├── .env.example             <- Variables de entorno (copiar como .env)
├── docs/
│   ├── ARQUITECTURA.md      <- Cómo está construido y por qué
│   └── DESPLIEGUE.md        <- Cómo ponerlo en línea con tu dominio
├── database/
│   └── schema.sql          <- Ejecutar en MySQL Workbench primero
├── backend/
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── .env.example        <- Copiar como .env y poner tus datos
│   ├── tests/               <- Pruebas automáticas (pytest)
│   └── app/
│       ├── main.py             <- Archivo que enciende el servidor
│       ├── database.py         <- Conexión a MySQL
│       ├── models.py           <- Tablas en formato Python
│       ├── schemas.py          <- Validación de datos
│       ├── security.py         <- Encriptado y tokens
│       ├── dependencies.py     <- Permisos por rol
│       ├── logging_config.py   <- Registro de eventos del sistema
│       └── routers/
│           ├── auth.py         <- Login
│           ├── productos.py    <- CRUD de productos
│           └── movimientos.py  <- Entradas/salidas (escaneo)
└── flutter_app/
    └── README.md            <- Siguiente fase (app)
```

## Opción A — Correrlo con Docker (recomendado, más "empresarial")
```bash
cp .env.example .env
nano .env   # pon tu password segura y tu secret key
docker compose up -d
```
Listo — backend + MySQL corriendo juntos en `http://localhost:8000/docs`.

## Opción B — Correrlo manualmente (para ir aprendiendo paso a paso)

## Paso 1 — Base de datos
1. Abre MySQL Workbench.
2. Abre el archivo `database/schema.sql`.
3. Ejecútalo completo (ícono del rayo ⚡ o Ctrl+Shift+Enter).
4. Deberías ver la base `inventario_db` creada con sus 5 tablas.

## Paso 2 — Backend (Python)
Necesitas tener Python 3.10+ instalado.

```bash
cd backend

# Crear un ambiente virtual (recomendado, mantiene todo ordenado)
python -m venv venv

# Activarlo
# En Windows:
venv\Scripts\activate
# En Mac/Linux:
source venv/bin/activate

# Instalar las librerías necesarias
pip install -r requirements.txt

# Configurar tus datos de conexión
copy .env.example .env      (Windows)
cp .env.example .env        (Mac/Linux)
```

Abre el archivo `.env` y pon tu usuario/contraseña real de MySQL.

## Paso 3 — Crear tu primer usuario administrador
Abre una terminal Python dentro de la carpeta `backend` y ejecuta:

```python
from app.database import SessionLocal
from app.models import Usuario, RolUsuario
from app.security import hash_password

db = SessionLocal()
admin = Usuario(
    nombre_completo="Tu Nombre",
    usuario="admin",
    password_hash=hash_password("admin123"),
    rol=RolUsuario.admin
)
db.add(admin)
db.commit()
print("Usuario admin creado")
```

## Paso 4 — Encender el servidor
```bash
uvicorn app.main:app --reload
```

Abre en tu navegador: **http://localhost:8000/docs**

Ahí verás una interfaz automática (Swagger) donde puedes PROBAR cada
función del sistema (login, crear productos, registrar entradas/salidas)
sin necesidad de tener la app de Flutter lista todavía. Esto es clave:
así vamos probando que el "cerebro" funciona bien antes de construir
la parte visual.

## Correr los tests automáticos
Esto confirma que las reglas críticas del negocio funcionan (por
ejemplo: que nunca se pueda sacar más stock del que hay):
```bash
cd backend
python -m pytest tests/ -v
```
Deberías ver `7 passed` en verde.

## Poner el sistema en línea con tu dominio
Lee `docs/DESPLIEGUE.md` — te explica paso a paso, desde cero, qué
hacer con tu dominio para que el sistema quede accesible en internet
con tu propio nombre y HTTPS.

## Siguiente paso
Una vez pruebes que el login y el registro de movimientos funcionan
bien desde `/docs`, seguimos con la app de Flutter que se conecta a
este mismo backend.
