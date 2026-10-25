# Feedback V0.02 — MiBodega.pe
### Revisión alineada a la especificación funcional (Proyecto 1 · inventario en 2 semanas)

| Campo | Valor |
|---|---|
| Documento | `FeedBack/feedback_V0.02.md` |
| Reemplaza a | `feedback_V0.01.md` (revisión solo de archivos, sin especificación) |
| Fecha | 2026-10-25 (domingo) |
| Ventana de entrega | **lun 26 oct → dom 8 nov 2026** (10 días hábiles + 1 fin de semana) |
| Nivel | Básico · Retail de barrio / minimarket |
| Stack declarado | HTML/CSS/JS · Node.js + Express · MySQL · Git/GitHub · Hosting |
| Alcance | 8 ítems del "alcance mínimo" + definición de terminado (demo pública, repo, README) |

---

## 1. Qué cambia respecto a V0.01

V0.01 describía el repo vacío. Con tu especificación, el diagnóstico cambia de **"no hay producto"** a **"hay un producto claro y ya hay un plazo"**. La buena noticia: el alcance mínimo es realista para este nivel, y **el repo actual ya cumple el 15 % del trabajo** (MySQL en contenedor + primera tabla).

Lo que la especificación **añade** a lo que existe:

| Requisito de tu spec | Estado hoy |
|---|---|
| CRUD de categorías | 🟠 Tabla creada, sin API ni UI |
| CRUD de productos | 🔴 No existe |
| Movimientos de entrada y salida | 🔴 No existe |
| Venta simple con reducción de stock | 🔴 No existe |
| Alerta configurable de stock bajo | 🔴 No existe |
| Búsqueda y filtros | 🔴 No existe |
| Dashboard de 5 indicadores | 🔴 No existe |
| Validación de formularios | 🔴 No existe |
| Demo desplegada + datos ficticios | 🔴 No existe |
| README con 5 decisiones técnicas | 🔴 No existe |

**Cobertura real del alcance: 1 de 10 ítems (10 %)** — y ese único ítem (categorías) está a un tercio, porque solo tiene tabla.

---

## 2. Correcciones obligatorias antes de escribir la primera línea de la app

Estas cuatro cosas, si no se hacen hoy, te costarán días al final (despliegue y demo pública):

1. **Borrar `backend/db/.git/`** — repo anidado sin commits que rompería el primer `git add`.
2. **Versionar `backend/db/schema.sql`** — hoy está fuera de Git.
3. **Montar el esquema en el contenedor** (`./backend/db:/docker-entrypoint-initdb.d:ro`) — si no, la BD arranca vacía.
4. **Sacar credenciales a `.env`** — hosting público exige configuración por variables, no valores hardcodeados.

> Añadido por la spec: el `schema.sql` deja de ser "un archivo" y pasa a ser **la migración v1 del proyecto**. Debe ser idempotente y describir el modelo completo, no solo categorías.

---

## 3. Modelo de datos mínimo (derivado del alcance, no inventado)

Seis tablas cubren los 8 ítems del alcance sin sobrar ni faltar:

```
categorias ──< productos ──< movimientos_stock
                  │
                  └──< venta_detalle >── ventas

configuracion (1 fila)  →  stock_minimo por defecto
```

### 3.1 `categorias`
| Columna | Tipo | Notas |
|---|---|---|
| `id` | INT AI PK | ya existe |
| `nombre` | VARCHAR(100) UNIQUE | ya existe |
| `created_at` | TIMESTAMP | ya existe |
| `activo` | TINYINT(1) DEFAULT 1 | para no romper productos al borrar una categoría |

### 3.2 `productos`
| Columna | Tipo | Notas |
|---|---|---|
| `id` | INT AI PK | |
| `codigo` | VARCHAR(40) UNIQUE | búsqueda rápida tipo escáner (opcional pero vale oro en la demo) |
| `nombre` | VARCHAR(150) | obligatorio |
| `categoria_id` | INT FK → `categorias` | `ON DELETE RESTRICT` |
| `precio_compra` | DECIMAL(10,2) | para valor de inventario |
| `precio_venta` | DECIMAL(10,2) | para ingresos |
| `stock_actual` | INT NOT NULL DEFAULT 0 | **caché** del libro de movimientos |
| `stock_minimo` | INT NULL | si es NULL → usa el global de `configuracion` |
| `activo` | TINYINT(1) DEFAULT 1 | baja lógica |
| `created_at` / `updated_at` | TIMESTAMP | auditoría |

Índices: `UNIQUE(codigo)`, `INDEX(categoria_id)`, `INDEX(nombre)`, `INDEX(stock_actual)`.

### 3.3 `movimientos_stock`
| Columna | Tipo | Notas |
|---|---|---|
| `id` | INT AI PK | |
| `producto_id` | INT FK | `ON DELETE RESTRICT` |
| `tipo` | ENUM('ENTRADA','SALIDA','AJUSTE') | SALIDA también la genera una venta |
| `cantidad` | INT | siempre positiva; el signo lo da `tipo` |
| `motivo` | VARCHAR(200) | "compra proveedor", "merma", "venta #12" |
| `venta_id` | INT NULL FK → `ventas` | trazabilidad venta ↔ movimiento |
| `created_at` | TIMESTAMP | |

Índice: `INDEX(producto_id, created_at)`.

### 3.4 `ventas`
| Columna | Tipo | Notas |
|---|---|---|
| `id` | INT AI PK | |
| `folio` | VARCHAR(20) UNIQUE | ej. `V-000012` |
| `total` | DECIMAL(10,2) | calculado en servidor, nunca confiado del cliente |
| `metodo_pago` | ENUM('EFECTIVO','YAPE','TARJETA') | Yape es lo que un reclutador peruano espera ver |
| `created_at` | TIMESTAMP | |

### 3.5 `venta_detalle`
| Columna | Tipo | Notas |
|---|---|---|
| `id` | INT AI PK | |
| `venta_id` | INT FK | `ON DELETE CASCADE` |
| `producto_id` | INT FK | |
| `cantidad` | INT | > 0 |
| `precio_unitario` | DECIMAL(10,2) | **copiado** al momento de la venta (histórico inmutable) |
| `subtotal` | DECIMAL(10,2) | `cantidad * precio_unitario` |

### 3.6 `configuracion`
| Columna | Tipo | Notas |
|---|---|---|
| `id` | TINYINT PK CHECK (=1) | fila única |
| `stock_minimo_default` | INT DEFAULT 5 | lo "configurable" de la alerta |
| `nombre_negocio` | VARCHAR(100) | se muestra en la demo |

**Decisión clave #1 (para el README):** el stock se guarda **dos veces** — como `productos.stock_actual` (lectura rápida) y como suma de `movimientos_stock` (verdad auditable). Se actualizan en la **misma transacción**. Alternativa descartada: calcular `SUM()` en cada consulta (simple, pero lento y sin historial de quién cambió qué).

---

## 4. Contrato de API REST (lo que hay que construir)

| Método | Ruta | Requisito de la spec que cubre |
|---|---|---|
| GET | `/api/categorias?q=&page=` | CRUD + búsqueda |
| POST | `/api/categorias` | CRUD + validación |
| PUT | `/api/categorias/:id` | CRUD |
| DELETE | `/api/categorias/:id` | CRUD (falla 409 si tiene productos) |
| GET | `/api/productos?q=&categoria=&bajo_stock=&page=` | Búsqueda y filtros |
| POST | `/api/productos` | CRUD + validación |
| PUT | `/api/productos/:id` | CRUD |
| DELETE | `/api/productos/:id` | CRUD (baja lógica) |
| GET | `/api/movimientos?producto=&tipo=&desde=&hasta=` | Movimientos + filtros |
| POST | `/api/movimientos` | Entrada / salida / ajuste |
| POST | `/api/ventas` | Venta simple (transacción) |
| GET | `/api/ventas?desde=&hasta=` | Historial (mínimo) |
| GET | `/api/dashboard` | Los 5 indicadores |
| GET | `/api/configuracion` · PUT | Alerta configurable |

**Decisión clave #2:** `POST /api/ventas` recibe solo `[{producto_id, cantidad}]` + método de pago. El **precio y el total los calcula el servidor**. Si el cliente manda precios, es un bug de seguridad clásico y un reclutador técnico lo detecta en 30 segundos.

**Decisión clave #3:** la venta se ejecuta en una transacción con `SELECT ... FOR UPDATE` sobre cada producto: verifica stock, inserta venta, inserta detalle, inserta movimientos, descuenta `stock_actual`, y hace `ROLLBACK` completo si algo falla. Sin esto, dos ventas simultáneas pueden dejar stock negativo.

---

## 5. Dashboard: los 5 indicadores exactos

Para que sean defendibles en una entrevista (no "cinco tarjetas bonitas"):

1. **Productos activos** (conteo) — tamaño del catálogo.
2. **Valor del inventario (S/)** = `SUM(stock_actual * precio_compra)` — el número que le importa al dueño.
3. **Ventas de hoy (S/)** = `SUM(total)` del día — caja del día.
4. **Unidades vendidas hoy** = `SUM(venta_detalle.cantidad)` del día — rotación.
5. **Productos en alerta** = `stock_actual <= COALESCE(stock_minimo, stock_minimo_default)` — el requisito diferenciador.

Extra barato que suma mucho: **top 5 productos más vendidos** (una consulta, un `LIMIT 5`).

---

## 6. Frontend: 4 pantallas, ni una más

| Pantalla | Contenido | Cubre |
|---|---|---|
| **Dashboard** | 5 tarjetas + tabla de productos en alerta | Dashboard + alerta |
| **Productos** | tabla con buscador, filtro por categoría, filtro "solo bajo stock", paginación, modal alta/edición, botones +/- stock | CRUD, búsqueda, filtros, movimientos |
| **Ventas** | buscador de producto, carrito simple, total, botón cobrar | Venta simple |
| **Categorías / Configuración** | CRUD de categorías + `stock_minimo_default` | CRUD, alerta configurable |

**Decisión clave #4:** JS vanilla con módulos ES + `fetch`, sin framework. Razón honesta y vendible: *"con 2 semanas, un framework me obliga a enseñar configuración en vez de lógica; con vanilla demuestro fundamentos y mi código se lee completo"*. Si el reclutador pide React, ya tienes la app funcionando para migrar.

**Decisión clave #5:** backend en capas mínimas — `routes/` → `controllers/` → `db/` (consultas SQL) con `mysql2/promise`. Sin ORM: SQL visible, transacciones explícitas, y demuestras que sabes qué hace tu base de datos.

---

## 7. Plan de 14 días (calendario real)

| Día | Fecha | Entregable verificable |
|---|---|---|
| **D1** | lun 26 oct | Fase 0 cerrada: repo anidado borrado, SQL versionado y montado, `.env` + `.env.example`, `healthcheck`, README esqueleto. `docker compose up` deja 6 tablas creadas. |
| **D2** | mar 27 oct | Express arranca, `/api/health`, conexión MySQL por pool, manejo de errores central, validaciones base. |
| **D3** | mié 28 oct | CRUD categorías completo + validación + pruebas con `curl`. |
| **D4** | jue 29 oct | CRUD productos + búsqueda + filtros + paginación. |
| **D5** | vie 30 oct | Movimientos (entrada/salida/ajuste) + `stock_actual` consistente. **Hito: backend de catálogo cerrado.** |
| **D6** | sáb 31 oct | `POST /api/ventas` transaccional + historial. |
| **D7** | dom 1 nov | `/api/dashboard` con los 5 indicadores + `/api/configuracion`. **Hito: API completa.** |
| **D8** | lun 2 nov | Frontend: layout, dashboard y productos (tabla, buscador, filtros). |
| **D9** | mar 3 nov | Frontend: modal producto, movimientos rápidos, pantalla de venta. |
| **D10** | mié 4 nov | Frontend: categorías, configuración, validaciones de formulario visibles. **Hito: app usable end-to-end.** |
| **D11** | jue 5 nov | Datos ficticios (seed: ~12 productos, 4 categorías, 20 ventas) + pulido de UI. |
| **D12** | vie 6 nov | **Despliegue**: hosting + MySQL gestionada, variables de entorno, demo pública viva. |
| **D13** | sáb 7 nov | README completo: instalación, modelo de datos (diagrama), capturas, usuario demo, **5 decisiones técnicas**. |
| **D14** | dom 8 nov | Buffer: arreglos del despliegue, prueba desde otro dispositivo, guion de demo de 2 minutos. **Entrega.** |

El orden no es casual: **backend completo antes de tocar el frontend**. Si el plazo se rompe, es preferible una demo con API probada y 3 pantallas que 4 pantallas conectadas a una API inestable.

### Si te atrasas, recorta en este orden

1. Historial de ventas con filtros → dejarlo en "últimas 10 ventas".
2. `codigo` de producto → búsqueda solo por nombre.
3. Filtros combinados → dejar solo buscador + "solo bajo stock".
4. Paginación → mostrar 50 y punto.

**Nunca recortes:** transacción de venta, validación de servidor, README, demo pública. Son los cuatro puntos que un reclutador revisa.

---

## 8. Definición de terminado (checklist literal de tu spec)

- [ ] **Enlace público funcional** — carga desde otro dispositivo, sin `localhost`.
- [ ] **Repositorio** — historial con commits por día (no un commit gigante el último día; eso se nota).
- [ ] **README** con: instalación paso a paso, modelo de datos, capturas, usuario demo, 5 decisiones técnicas.
- [ ] CRUD productos y categorías operativo.
- [ ] Movimientos de entrada y salida registrados con motivo.
- [ ] Venta simple que descuenta stock (verificable: stock antes → stock después).
- [ ] Alerta de stock bajo visible en dashboard y configurable.
- [ ] Búsqueda y filtros funcionando.
- [ ] Dashboard con 5 indicadores con datos reales.
- [ ] Validación de formularios (cliente) **y** de servidor (probable con `curl`).
- [ ] Demo con datos ficticios cargados.

---

## 9. Hosting: decisión a tomar el D12, no el D14

| Opción | Ventaja | Coste real |
|---|---|---|
| **VPS propio + Docker Compose + Caddy** | Reproduce tu entorno local tal cual; MySQL en el mismo host | ~US$4–6/mes; requiere backups manuales |
| **Render/Railway (app) + MySQL gestionada** | Deploy por `git push`, URL inmediata | Planes gratuitos duermen o caducan; verificar límites antes |
| **Hosting compartido** | Barato | ❌ No soporta Node ni MySQL propio con comodidad |

Recomendación para portafolio: **VPS + Docker** si ya tienes uno; si no, Railway/Render para la app y una MySQL gestionada gratuita. Lo importante: que el enlace público **no dependa de tu laptop encendida**.

⚠️ Si usas un servicio gratuito, pon en el README un aviso: *"la demo puede tardar ~30 s en despertar"*. Evita que el reclutador crea que está roto.

---

## 10. Riesgos del plazo

| Riesgo | Señal temprana | Mitigación |
|---|---|---|
| Modelo de datos incompleto a mitad de semana | Cambias el SQL el D5 | Congelar las 6 tablas el **D1**; cambios solo por migración nueva |
| Stock inconsistente | `stock_actual` ≠ `SUM(movimientos)` | Script de verificación al final de cada día de backend |
| Despliegue falla el D12 | Nunca probaste variables de entorno | Probar el D3 un deploy "en blanco" a la plataforma elegida |
| UI se come el tiempo | El D9 no hay venta funcionando | Pantallas sin CSS bonito primero; estilos al D11 |
| Sin capturas para el README | No hay demo estable | Capturar el D13 con la demo ya desplegada |

**Verificación de consistencia de stock (útil desde el D5):**

```sql
SELECT p.id, p.nombre, p.stock_actual,
       COALESCE(SUM(CASE m.tipo WHEN 'ENTRADA' THEN m.cantidad
                                WHEN 'SALIDA'  THEN -m.cantidad
                                ELSE m.cantidad END), 0) AS calculado
FROM productos p
LEFT JOIN movimientos_stock m ON m.producto_id = p.id
GROUP BY p.id
HAVING p.stock_actual <> calculado;
-- Esperado: 0 filas. Si devuelve filas, hay un bug de transacción.
```

---

## 11. Texto para tu CV — ajuste sugerido

El original está bien. Dos mejoras que lo hacen verificable:

> "Desarrollé **MiBodega.pe**, una aplicación web de inventario para retail de barrio con registro de ventas, control de movimientos y alertas de stock bajo. Implementé una **API REST en Node.js/Express sobre MySQL**, con **ventas transaccionales** que descuentan stock de forma atómica, validación en cliente y servidor, y **despliegue público** con [hosting]. Dashboard de 5 indicadores y datos de demostración."

Añadir al lado: `Demo · Repositorio · README`. Un enlace vale más que cualquier adjetivo.

---

## 12. Preguntas para cerrar el V0.03 (definitivo, sin cambios de alcance)

1. **¿Precio de compra y de venta separados?** El modelo los incluye para poder mostrar "valor del inventario"; si no los quieres, se simplifica.
2. **¿Yape/Plin en el método de pago?** Lo propuse por contexto peruano; ¿lo dejo como texto libre o lista cerrada?
3. **¿Ventas con cliente registrado o venta anónima?** Tu spec no menciona clientes; mi versión es anónima (más rápido). ¿Confirmas?
4. **¿Usuario demo con login o app abierta sin autenticación?** Tu spec no pide auth. Sin login, la demo se revisa en 1 clic (mi recomendación); con login, demuestra más pero cuesta medio día.
5. **¿Hosting ya decidido?** Si tienes VPS o dominio `.pe`, cambia el plan del D12.
6. **¿Quién escribe el código?** Si lo haces tú, este documento es tu hoja de ruta; si quieres que yo lo implemente, dime por dónde empiezo (D1 o directamente el modelo completo del D1+D2).

---

## 13. Anexo — estado del repo vs. spec (comando de verificación)

```bash
cd MiBodega.pe

# ¿Cumple el esquema el alcance mínimo? Debe listar 6 tablas.
docker compose up -d
docker exec -it mibodega-db \
  mysql -ubodega -pbodega1234 -e "SHOW TABLES;" mibodega
# Hoy devuelve: (vacío)  → 0 de 6 tablas del alcance

# ¿Está todo en Git?
git status --short
# Hoy: ?? backend/   → hay trabajo sin respaldar
```

**Conclusión:** el alcance es alcanzable en 14 días **solo si** el D1 se dedica a saneamiento y a congelar el modelo de datos. El mayor riesgo del proyecto no es técnico: es empezar el frontend antes de tener la API estable y llegar al día 12 sin despliegue probado.
