# App Flutter — Próxima fase

Esta carpeta está reservada para la app en Flutter (PC y celular).

No la creamos todavía porque primero debemos confirmar que el backend
(Python + MySQL) funciona perfecto — es el "cerebro" del sistema.
Cuando lo hayamos probado desde `/docs`, el siguiente paso será:

1. Correr `flutter create inventario_app` en esta carpeta (desde tu PC,
   ya que Flutter necesita su SDK instalado localmente).
2. Conectar la app al backend usando peticiones HTTP (paquete `http` o `dio`).
3. Agregar el paquete `mobile_scanner` (o `qr_code_scanner`) para leer
   códigos de barras/QR desde la cámara.
4. Construir las pantallas: login, dashboard, escaneo, entrada/salida.

Esto lo hacemos juntos paso a paso cuando lleguemos a esa fase.
