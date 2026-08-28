# Guía de despliegue — Poner el sistema "en vivo" con tu dominio

## Primero, entendamos las piezas (sin tecnicismos)

Tener un **dominio** (ej: `miempresa.com`) es solo el "nombre" —
como tener el nombre de tu negocio registrado. Pero un nombre solo,
sin nada más, no hace nada. Te faltan 2 piezas:

1. **Un servidor** (un computador encendido 24/7 en internet) donde
   vive tu sistema. Esto se renta, se llama VPS (Servidor Privado
   Virtual). Ejemplos: DigitalOcean, Hetzner, AWS, Contabo.
2. **Configurar el dominio** para que apunte a ese servidor (esto se
   llama DNS — como decirle a Google Maps "esta dirección exacta es
   la de mi negocio").

## Analogía simple
- **Dominio** = el nombre de tu tienda ("Ferretería El Tornillo")
- **Servidor (VPS)** = el local físico donde de verdad está la tienda
- **DNS** = el directorio que le dice a la gente en qué dirección
  exacta queda tu tienda cuando buscan el nombre

## Paso 1 — Conseguir un servidor (VPS)

Recomendación para empezar (barato y suficiente para tu caso):
- **DigitalOcean** o **Hetzner** — desde $5-6 USD/mes
- Eliges: Ubuntu 22.04, el plan más básico

Al crear el servidor te dan una **IP** (ej: `164.90.123.45`) — esa es
la "dirección real" de tu servidor.

## Paso 2 — Apuntar tu dominio a esa IP

Entras a donde compraste tu dominio (GoDaddy, Namecheap, etc.), buscas
la sección **DNS** y agregas:

| Tipo | Nombre | Valor |
|---|---|---|
| A | @ | 164.90.123.45 (la IP de tu servidor) |
| A | api | 164.90.123.45 |

Esto hace que `miempresa.com` y `api.miempresa.com` apunten a tu
servidor. Tarda entre 10 minutos y unas horas en activarse.

## Paso 3 — Instalar el sistema en el servidor

Te conectas al servidor por SSH (una terminal remota) y ejecutas:

```bash
# Instalar Docker (una sola vez)
curl -fsSL https://get.docker.com | sh

# Subir tu proyecto (con git, o copiando los archivos)
git clone tu-repositorio.git
cd inventario_proyecto

# Configurar tus claves
cp .env.example .env
nano .env    # pones tu password segura y tu secret key

# Levantar todo
docker compose up -d
```

Con esto, tu backend queda corriendo en el puerto 8000 del servidor.

## Paso 4 — HTTPS (candado de seguridad) con Nginx + Certbot

Para que tu dominio funcione con `https://` (obligatorio para verse
profesional y seguro), se instala un "proxy" llamado Nginx y se le
pide un certificado gratis a Let's Encrypt:

```bash
sudo apt install nginx certbot python3-certbot-nginx -y
sudo certbot --nginx -d api.miempresa.com
```

Certbot configura todo automáticamente y renueva el certificado solo.

## Resultado final

- `https://api.miempresa.com/docs` → documentación de tu API
- Tu app en Flutter se conecta a `https://api.miempresa.com`
- Todo con candado de seguridad (HTTPS), tu dominio propio, corriendo
  24/7 en un servidor real — nivel empresarial de verdad.

## Nota importante
Este paso (Servidor + DNS + Nginx) se hace UNA vez y con calma —
no es algo que tengas que resolver hoy mismo. Primero terminamos de
probar todo en tu PC (con Docker local), y cuando estés seguro de que
todo funciona bien, replicamos exactamente lo mismo en el servidor.
