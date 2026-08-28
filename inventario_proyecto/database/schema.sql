-- ============================================
-- BASE DE DATOS: Sistema de Inventario
-- Ejecutar este script completo en MySQL Workbench
-- ============================================

CREATE DATABASE IF NOT EXISTS invplex_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE invplex_db;

-- ------------------------------------------------
-- Tabla: secciones (Planta, Administración, Bodega)
-- ------------------------------------------------
CREATE TABLE secciones (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    descripcion VARCHAR(255)
);

INSERT INTO secciones (nombre, descripcion) VALUES
    ('Planta', 'Inventario de planta de producción'),
    ('Administracion', 'Inventario de oficinas administrativas'),
    ('Bodega', 'Inventario general de bodega');

-- ------------------------------------------------
-- Tabla: usuarios
-- ------------------------------------------------
CREATE TABLE usuarios (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre_completo VARCHAR(150) NOT NULL,
    usuario VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    rol ENUM('admin', 'supervisor', 'operario') NOT NULL DEFAULT 'operario',
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------
-- Tabla: proveedores (opcional, útil a futuro)
-- ------------------------------------------------
CREATE TABLE proveedores (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    contacto VARCHAR(150),
    telefono VARCHAR(50),
    email VARCHAR(150)
);

-- ------------------------------------------------
-- Tabla: productos
-- ------------------------------------------------
CREATE TABLE productos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    codigo_barras VARCHAR(100) UNIQUE,      -- código escaneado (QR o barras)
    nombre VARCHAR(150) NOT NULL,
    categoria VARCHAR(100),
    seccion_id INT NOT NULL,
    proveedor_id INT NULL,
    stock_actual INT NOT NULL DEFAULT 0,
    stock_minimo INT NOT NULL DEFAULT 0,
    unidad_medida VARCHAR(30) DEFAULT 'unidad',
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (seccion_id) REFERENCES secciones(id),
    FOREIGN KEY (proveedor_id) REFERENCES proveedores(id),
    INDEX idx_codigo_barras (codigo_barras)
);

-- ------------------------------------------------
-- Tabla: movimientos (entradas/salidas -> trazabilidad)
-- ------------------------------------------------
CREATE TABLE movimientos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    producto_id INT NOT NULL,
    usuario_id INT NOT NULL,
    tipo ENUM('entrada', 'salida') NOT NULL,
    cantidad INT NOT NULL,
    stock_resultante INT NOT NULL,   -- stock que quedó después del movimiento
    motivo VARCHAR(255),
    fecha DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (producto_id) REFERENCES productos(id),
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
    INDEX idx_producto (producto_id),
    INDEX idx_fecha (fecha)
);

-- ------------------------------------------------
-- Usuario administrador inicial
-- (contraseña: admin123 -> se debe cambiar luego)
-- El hash se genera desde el backend, este es un placeholder
-- ------------------------------------------------
-- INSERT INTO usuarios (nombre_completo, usuario, password_hash, rol)
-- VALUES ('Administrador', 'admin', '<hash_generado_por_backend>', 'admin');
