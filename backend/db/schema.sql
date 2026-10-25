-- ============================================================
-- MiBodega.pe — Esquema v1
-- Motor: MySQL 8.4 · Charset: utf8mb4 · Engine: InnoDB
-- Ejecutado automáticamente por el contenedor al inicializar
-- el volumen (docker-entrypoint-initdb.d).
-- Idempotente: puede ejecutarse varias veces sin error.
-- ============================================================

SET NAMES utf8mb4;

-- ------------------------------------------------------------
-- 1. categorias
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS categorias (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nombre     VARCHAR(100) NOT NULL,
  activo     TINYINT(1)   NOT NULL DEFAULT 1,
  created_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_categorias_nombre (nombre)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ------------------------------------------------------------
-- 2. productos
-- stock_actual es una CACHÉ del libro de movimientos.
-- La fuente de verdad es la suma de movimientos_stock.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS productos (
  id            INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  codigo        VARCHAR(40)   NULL,                 -- código de barras / SKU
  nombre        VARCHAR(150)  NOT NULL,
  categoria_id  INT UNSIGNED  NOT NULL,
  precio_compra DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  precio_venta  DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  stock_actual  INT           NOT NULL DEFAULT 0,
  stock_minimo  INT           NULL,                 -- NULL => usa configuracion.stock_minimo_default
  activo        TINYINT(1)    NOT NULL DEFAULT 1,
  created_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_productos_codigo (codigo),
  KEY idx_productos_categoria (categoria_id),
  KEY idx_productos_nombre (nombre),
  KEY idx_productos_stock (stock_actual),
  CONSTRAINT fk_productos_categoria
    FOREIGN KEY (categoria_id) REFERENCES categorias (id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_productos_precios
    CHECK (precio_compra >= 0 AND precio_venta >= 0),
  CONSTRAINT chk_productos_stock
    CHECK (stock_actual >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ------------------------------------------------------------
-- 3. ventas (cabecera)
-- El total lo calcula SIEMPRE el servidor, nunca el cliente.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ventas (
  id          INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  folio       VARCHAR(20)   NOT NULL,               -- ej. V-000012
  total       DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  metodo_pago ENUM('EFECTIVO','YAPE','TARJETA') NOT NULL DEFAULT 'EFECTIVO',
  created_at  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_ventas_folio (folio),
  KEY idx_ventas_fecha (created_at),
  CONSTRAINT chk_ventas_total CHECK (total >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ------------------------------------------------------------
-- 4. venta_detalle
-- precio_unitario se COPIA al momento de la venta (histórico inmutable).
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS venta_detalle (
  id              INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  venta_id        INT UNSIGNED  NOT NULL,
  producto_id     INT UNSIGNED  NOT NULL,
  cantidad        INT           NOT NULL,
  precio_unitario DECIMAL(10,2) NOT NULL,
  subtotal        DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_detalle_venta (venta_id),
  KEY idx_detalle_producto (producto_id),
  CONSTRAINT fk_detalle_venta
    FOREIGN KEY (venta_id) REFERENCES ventas (id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_detalle_producto
    FOREIGN KEY (producto_id) REFERENCES productos (id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_detalle_cantidad CHECK (cantidad > 0),
  CONSTRAINT chk_detalle_subtotal CHECK (subtotal >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ------------------------------------------------------------
-- 5. movimientos_stock (libro mayor de existencias)
-- cantidad siempre positiva; el signo lo determina el tipo.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS movimientos_stock (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  producto_id INT UNSIGNED NOT NULL,
  tipo        ENUM('ENTRADA','SALIDA','AJUSTE') NOT NULL,
  cantidad    INT          NOT NULL,
  motivo      VARCHAR(200) NULL,
  venta_id    INT UNSIGNED NULL,                    -- trazabilidad venta <-> movimiento
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_mov_producto_fecha (producto_id, created_at),
  KEY idx_mov_venta (venta_id),
  CONSTRAINT fk_mov_producto
    FOREIGN KEY (producto_id) REFERENCES productos (id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_mov_venta
    FOREIGN KEY (venta_id) REFERENCES ventas (id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT chk_mov_cantidad CHECK (cantidad > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ------------------------------------------------------------
-- 6. configuracion (fila única)
-- Aquí vive lo "configurable" de la alerta de stock bajo.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS configuracion (
  id                   TINYINT UNSIGNED NOT NULL DEFAULT 1,
  nombre_negocio       VARCHAR(100) NOT NULL DEFAULT 'Mi Bodega',
  stock_minimo_default INT          NOT NULL DEFAULT 5,
  updated_at           TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT chk_configuracion_unica CHECK (id = 1),
  CONSTRAINT chk_configuracion_stock CHECK (stock_minimo_default >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO configuracion (id) VALUES (1)
  ON DUPLICATE KEY UPDATE id = id;
