ruta = "lib/screens/ver_producto_screen.dart"
with open(ruta, "r", encoding="utf-8") as f:
    c = f.read()

viejo = """        SnackBar(content: Text('Proveedor actualizado a "\\${elegido['nombre']}"'), backgroundColor: Colors.green),"""
nuevo = """        SnackBar(content: Text('Proveedor actualizado a "${elegido['nombre']}"'), backgroundColor: Colors.green),"""

assert c.count(viejo) == 1, f"aparecio {c.count(viejo)} veces"
c = c.replace(viejo, nuevo, 1)

with open(ruta, "w", encoding="utf-8") as f:
    f.write(c)
print("Corregido.")
