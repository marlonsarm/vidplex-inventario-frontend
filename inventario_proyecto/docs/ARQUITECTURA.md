# Arquitectura del Sistema

## Visión general

```
┌─────────────┐         ┌──────────────────┐         ┌─────────────┐
│   Flutter    │  HTTPS  │      Backend      │  SQL    │    MySQL     │
│ (PC/Celular) │ ───────>│  Python/FastAPI   │────────>│  Base datos  │
└─────────────┘         └──────────────────┘         └─────────────┘
                                  │
                                  ▼
                            logs/inventario.log
```

## Capas del backend

1. **Rutas (routers/)** — reciben las peticiones HTTP (login, crear
   producto, registrar movimiento). No contienen lógica de negocio,
   solo coordinan.
2. **Seguridad (dependencies.py, security.py)** — verifica quién eres
   (token) y qué puedes hacer (rol). Se ejecuta ANTES de que tu petición
   llegue a la lógica real.
3. **Modelos (models.py)** — representación de las tablas de MySQL.
4. **Esquemas (schemas.py)** — validan que los datos que entran/salen
   tengan el formato correcto (nunca se procesan datos "raros").
5. **Base de datos (database.py)** — maneja las conexiones de forma
   segura, cerrándolas siempre después de usarlas.

## Principio de menor privilegio (seguridad)

| Rol | Puede ver productos | Puede crear productos | Puede hacer entradas/salidas | Administra usuarios |
|---|---|---|---|---|
| Operario | ✅ | ❌ | ✅ | ❌ |
| Supervisor | ✅ | ✅ | ✅ | ❌ |
| Admin | ✅ | ✅ | ✅ | ✅ |

Cada endpoint valida el rol del usuario ANTES de ejecutar cualquier
acción. Esto se hace en el backend (no se puede "hackear" desde la
app, porque la validación real ocurre del lado del servidor).

## Por qué el sistema "no falla"

- **Transacciones atómicas**: un movimiento de stock o se guarda
  completo, o no se guarda nada — nunca queda a medias.
- **Manejador global de errores**: si algo inesperado ocurre en
  cualquier parte del sistema, se registra en logs y se responde
  algo claro, en vez de que el servidor se caiga.
- **Tests automáticos**: antes de cualquier cambio al código, los
  tests confirman que las reglas críticas (nunca stock negativo,
  login obligatorio) se sigan cumpliendo.
- **Logs rotativos**: cada acción importante queda registrada con
  fecha, usuario y resultado — si algo falla, se puede investigar
  exactamente qué pasó.
- **Docker**: el sistema corre exactamente igual en tu PC, en un
  servidor de pruebas, o en producción — elimina el clásico
  "en mi computador sí funciona".
