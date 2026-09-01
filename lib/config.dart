class AppConfig {
  // Cambia esto según dónde pruebes la app:
  // Chrome (PC):        http://localhost:8000
  // Emulador Android:   http://10.0.2.2:8000
  // Celular físico:     http://TU_IP_LOCAL:8000
static const String baseUrl = "https://vidplex-inventario-backend-production.up.railway.app";

  // Versión de ESTE build. Súbela cada vez que hagas un cambio que quieras
  // forzar a todos a tomar (junto con VERSION_MINIMA_FRONTEND en el backend).
  static const String appVersion = "1.0.0";
}