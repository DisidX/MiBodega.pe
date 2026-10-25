# Feedback V0.01 — MiBodega.pe

| Campo | Valor |
|---|---|
| Documento | `FeedBack/feedback_V0.01.md` |
| Fecha | 2026-10-25 |
| Alcance | Revisión estática de **todos** los archivos versionados y no versionados dentro de `MiBodega.pe/` |
| Método | Lectura directa de archivos + `git log` / `git status` + inspección del árbol de directorios |
| Fuente del diseño esperado | ❌ **Pendiente**: la imagen/captura con la visión del proyecto no pudo ser leída, por lo que este informe se basa únicamente en el código existente |

---

## 1. Resumen ejecutivo

El proyecto está en **fase 0: esqueleto**. Existe la infraestructura de base de datos (docker-compose con MySQL 8.4) y **una sola tabla** (`categorias`). No hay aplicación: `backend/` no tiene código, `frontend/` está completamente vacía.

En números:

- **2** archivos de contenido real: `docker-compose.yml` (17 líneas) y `backend/db/schema.sql` (5 líneas).
- **1** commit en el historial (`c637746 chore: base initial with compose MySQL 8.4`).
- **0** archivos de aplicación (sin `package.json`, sin código fuente, sin tests, sin README).
- **1** repositorio Git anidado por error en `backend/db/.git`.
- **1** carpeta de trabajo (`backend/`) **sin versionar**: el riesgo más alto hoy es perderla.

Estado por componente:

| Componente | Estado | Comentario |
|---|---|---|
| Base de datos (contenedor) | 🟡 Definida, no operativa | Compose correcto pero sin healthcheck ni init automático |
| Modelo de datos | 🔴 1 tabla de 8+ necesarias | Solo `categorias`; sin productos, ventas, stock, usuarios |
| Backend / API | 🔴 No existe | `backend/` vacío salvo SQL |
| Frontend | 🔴 No existe | `frontend/` vacía |
| Configuración / secretos | 🔴 Credenciales en claro | `root1234` / `bodega1234` dentro del compose |
| Repositorio Git | 🟡 Incompleto | Un commit, trabajo nuevo sin trackear, repo anidado |
| Documentación | 🔴 Inexistente | Sin README, sin `.env.example` |
| Pruebas / CI | 🔴 Inexistente | Sin tests, sin pipeline |

**Diagnóstico en una frase:** hay cimientos de infraestructura, pero todavía no hay producto; y lo poco que hay de valor (el `schema.sql`) no está guardado en Git.

---

## 2. Inventario real del proyecto

```
MiBodega.pe/
├── .git/                      (1 commit: c637746)
├── .gitignore                 (2 líneas)
├── docker-compose.yml         (17 líneas — MySQL 8.4)
├── backend/
│   └── db/
│       ├── .git/              ⚠️ repositorio Git anidado, sin commits
│       └── schema.sql         (5 líneas — tabla categorias)  [sin versionar]
└── frontend/                  (vacía)
```

### 2.1 `docker-compose.yml`

Define un único servicio `db`:

- Imagen `mysql:8.4`, contenedor `mibodega-db`, `restart: unless-stopped`.
- Base de datos `mibodega`, usuario `bodega`, contraseña `bodega1234`, root `root1234`.
- Puerto `3306:3306` (publicado en **todas** las interfaces de red).
- Volumen nombrado `db_data` → `/var/lib/mysql`.

Lo que está bien: imagen reciente, volumen persistente, política de reinicio, política de nombres clara.

### 2.2 `backend/db/schema.sql`

```sql
CREATE TABLE IF NOT EXISTS categorias(
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL UNIQUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

Es la única definición de datos del proyecto. Es una tabla "catálogo" sin relaciones todavía.

### 2.3 `.gitignore`

Solo `node_modules/` y `.env`. Es la única pista sobre el stack previsto: sugiere un ecosistema **JavaScript/Node**, pero **no hay ningún `package.json` que lo confirme**.

### 2.4 `frontend/`

Carpeta vacía (0 bytes). No hay framework, ni build, ni assets.

---

## 3. Hallazgos por severidad

### 🔴 P0 — Bloqueantes / riesgo de pérdida

1. **`backend/` no está versionado.** `git status` muestra `?? backend/`. Todo el SQL vive fuera de Git: un `git clean -xfd` o un borrado accidental lo elimina sin recuperación.
2. **Repositorio Git anidado en `backend/db/.git`.** No tiene commits (`HEAD → refs/heads/master`) y no aporta nada. Al añadir `backend/` al repo principal, Git lo tratará como *embedded repository* y guardará una referencia vacía en lugar del contenido, generando un fallo silencioso clásico. **Debe eliminarse antes de hacer commit.**
3. **No existe init de base de datos.** `schema.sql` **no está montado** en `/docker-entrypoint-initdb.d/`. Consecuencia: al levantar el compose, la base `mibodega` queda **vacía**; la tabla `categorias` nunca se crea automáticamente. Quien clone el repo obtiene un contenedor sin esquema.
4. **No hay `.env.example` ni variables de entorno.** Sin plantilla, nadie puede reproducir el entorno sin leer el compose y adivinar valores.

### 🟠 P1 — Seguridad y operación

5. **Credenciales en texto plano y versionadas.** `root1234` y `bodega1234` están en un archivo que ya está en Git. Además, son débiles y reutilizables. Deberían venir de `.env` (ya ignorado) y el `.env.example` solo con placeholders.
6. **MySQL expuesto en `0.0.0.0:3306`.** En una laptop con red pública o Wi-Fi compartida, la base queda accesible desde la LAN. Lo correcto en desarrollo es `127.0.0.1:3306:3306`.
7. **Sin `healthcheck`.** Ni el compose ni los servicios futuros pueden saber cuándo MySQL está realmente listo; aparecerán errores intermitentes de "connection refused" al arrancar el backend.
8. **Sin política de backups del volumen `db_data`.** Un volumen nombrado sobrevive a `docker compose down`, pero no a un `down -v` ni a un fallo de disco.
9. **Sin límites de recursos ni versión fijada por digest.** `mysql:8.4` está bien; considerar `8.4.x` exacto para builds reproducibles.

### 🟡 P2 — Arquitectura y mantenibilidad

10. **Modelo de datos incompleto.** Una tabla `categorias` sin `productos` deja el dominio sin sentido: falta el núcleo (productos, stock/movimientos, ventas, detalle de venta, clientes, proveedores, usuarios/roles, caja).
11. **Sin estrategia de migraciones.** Un `schema.sql` suelto no escala: no hay versionado del esquema ni rollback.
12. **Sin convenciones declaradas.** No hay decisión escrita sobre nombres (¿`snake_case`?), zona horaria (`created_at` sin `TZ` explícita), moneda/IGV, ni soft-deletes.
13. **Sin stack definido.** No hay `package.json`, `requirements.txt`, `composer.json` ni `Dockerfile`. El `.gitignore` insinúa Node, pero es una inferencia, no un hecho.
14. **`.gitignore` incompleto.** Faltan patrones típicos: `dist/`, `build/`, `.env.*`, `*.log`, `__pycache__/`, `.venv/`, `coverage/`, `.DS_Store`, dumps `*.sql.gz`.
15. **Sin README.** No hay cómo levantar el proyecto en 5 líneas, ni descripción del producto, ni estado del roadmap.
16. **`frontend/` vacía y versionada de facto.** Una carpeta vacía no se trackea en Git; si el frontend debe existir desde ya, necesita al menos un archivo base.

---

## 4. Riesgos concretos si se sigue así

| Riesgo | Probabilidad | Impacto |
|---|---|---|
| Pérdida del `schema.sql` por no estar en Git | Media | Alto |
| El esquema no se crea al clonar (init no montado) | **Alta** | Alto |
| Commit con repositorio anidado y código "invisible" | **Alta** | Medio |
| Fuga de credenciales de BD (ya están en el historial) | Media | Alto |
| Retrabajo por falta de migraciones al crecer el modelo | Alta | Medio |
| Bloqueo del frontend por no definir contrato de API | Media | Medio |

---

## 5. Plan de acción propuesto

### Fase 0 — Saneamiento (hoy, ~30 min)

1. Borrar `backend/db/.git/`.
2. Añadir `backend/db/schema.sql` y el resto de `backend/` al repo principal; commit `feat(db): add initial schema`.
3. Montar el esquema en el contenedor: volumen de solo lectura `./backend/db/init:/docker-entrypoint-initdb.d:ro`.
4. Mover credenciales a `.env` + crear `.env.example`; cambiar `3306:3306` por `127.0.0.1:3306:3306`.
5. Añadir `healthcheck` a MySQL (`mysqladmin ping`).
6. Completar `.gitignore` y crear `README.md` mínimo.

**Criterio de aceptación:** `docker compose up -d` en una máquina limpia deja MySQL *healthy* y la tabla `categorias` creada, sin pasos manuales.

### Fase 1 — Modelo de datos completo

- Diseñar el dominio mínimo: `usuarios`, `categorias`, `productos`, `movimientos_stock`, `ventas`, `venta_detalle`, `clientes`, `proveedores`.
- Definir claves foráneas, índices, tipos monetarios (`DECIMAL(10,2)`), zona horaria y campos de auditoría.
- Adoptar migraciones versionadas desde el principio.

**Criterio de aceptación:** esquema reproducible desde cero y diagrama entidad-relación en `docs/`.

### Fase 2 — Backend / API

- Definir contrato (OpenAPI) antes de codificar.
- CRUD de catálogos + lógica de stock y ventas en transacción.
- Validación, manejo de errores uniforme, seed de datos demo.

**Criterio de aceptación:** endpoints documentados y probados; una venta descuenta stock de forma atómica.

### Fase 3 — Frontend

- Scaffold del framework elegido, layout base y conexión al API.
- Flujo crítico primero: registrar venta → ver stock actualizado.

### Fase 4 — Operación

- CI (lint + tests), backups del volumen, entornos `dev/prod`, logs.

---

## 6. Decisiones pendientes (necesito tu confirmación)

1. **¿Stack del backend?** (Node/Express, NestJS, Laravel, Django…). El `.gitignore` sugiere Node, ¿es correcto?
2. **¿Stack del frontend?** (React+Vite, Next.js, Vue, Svelte…).
3. **¿Qué alcance funcional tiene MiBodega.pe?** ¿Es punto de venta de bodega (productos, stock, ventas, caja), o también compras/proveedores, clientes con crédito, reportes?
4. **¿Una sola bodega o varias (multi-negocio)?** Cambia todo el modelo de datos desde el día uno.
5. **¿Moneda y tributos?** Soles (PEN), ¿IGV 18% incluido o desglosado?, ¿comprobantes electrónicos?
6. **¿Autenticación y roles?** ¿Quién entra: dueño, cajero, almacenero?
7. **¿La imagen del diseño que enviaste?** No pude leerla. Si me pasas el texto (pantallas, módulos, colores, flujo), este documento pasa a V0.02 alineado a tu visión real.

---

## 7. Anexo — Cómo verificar el estado actual

```bash
cd MiBodega.pe

# 1. ¿Qué hay realmente?
find . -path ./.git -prune -o -type f -print

# 2. ¿Qué está fuera de Git?
git status --short

# 3. ¿Hay repos anidados?
find . -name .git -type d -not -path ./.git

# 4. ¿Se crea el esquema al levantar?
docker compose up -d && docker exec -it mibodega-db \
  mysql -ubodega -pbodega1234 -e "SHOW TABLES;" mibodega
# Esperado hoy: lista vacía  → confirma el hallazgo P0-3
```

---

**Conclusión:** el proyecto está correctamente *iniciado* (infraestructura clara y ordenada) pero aún **no empezado** en lo que importa: no hay datos, ni API, ni interfaz. La prioridad inmediata no es escribir features, sino **asegurar el esquema en Git y hacer que el entorno se reproduzca solo**. Con eso resuelto, el resto avanza rápido.
