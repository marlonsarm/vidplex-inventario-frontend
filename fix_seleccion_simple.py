ruta = "lib/screens/dashboard_screen.dart"
with open(ruta, "r", encoding="utf-8") as f:
    c = f.read()

viejo = """                    decoration: BoxDecoration(
                      color: seleccionado ? AppColors.acento.withValues(alpha: 0.14) : AppColors.negro2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: seleccionado
                            ? AppColors.acento
                            : (stockBajo ? AppColors.ambarBajo.withValues(alpha: 0.5) : AppColors.grisLinea),
                        width: seleccionado ? 2 : 1,
                      ),"""

nuevo = """                    decoration: BoxDecoration(
                      color: AppColors.negro2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: seleccionado
                            ? AppColors.acento
                            : (stockBajo ? AppColors.ambarBajo.withValues(alpha: 0.5) : AppColors.grisLinea),
                        width: 1,
                      ),"""

assert c.count(viejo) == 1, f"aparecio {c.count(viejo)} veces"
c = c.replace(viejo, nuevo, 1)

with open(ruta, "w", encoding="utf-8") as f:
    f.write(c)
print("Aplicado correctamente.")
