# DomiQuibdó — Sprint 0

App de domicilios para restaurantes pequeños de Quibdó, Chocó. Proyecto de la materia Electiva 5 (UNICLARETIANA).

Está inspirada en **Aki Quibdo**, una app local que suspendió operaciones en 2022 por motivos de seguridad. Por eso la **seguridad del repartidor y del cliente es un requisito de diseño**:

- código de verificación de entrega
- botón SOS
- compartir ubicación
- zonas de cobertura por barrio

```
domiQuibdo/
  backend/   Laravel 13 + PostgreSQL + Sanctum (API REST)
  app/       Flutter (web + Android) · Material 3 · flutter_map + OpenStreetMap
```

## Requisitos
- PHP 8.3+ con `pdo_pgsql`, Composer
- PostgreSQL (probado con 17)
- Flutter 3.41+

## 1. Backend

```bash
cd backend
composer install
cp .env.example .env   # luego ajustar DB_* (pgsql) y agregar APP_DEMO=true
php artisan key:generate
createdb domiquibdo && createdb domiquibdo_test
php artisan migrate:fresh --seed
php artisan serve --host=0.0.0.0 --port=8000
```

Tests (usan la BD `domiquibdo_test`):

```bash
php artisan test
```

Antes de presentar, `php artisan migrate:fresh --seed` deja la base limpia. Queda un pedido #1 "en camino", listo para abrir el tracking.

### Cuentas demo (contraseña: `password`)
| Rol | Correo |
|---|---|
| Cliente | `cliente@demo.co` |
| Repartidor | `repartidor@demo.co` |
| Restaurante | `restaurante@demo.co` |
| Admin | `admin@demo.co` |

### API (prefijo `/api`, token Bearer de Sanctum)
| Método | Ruta | Descripción |
|---|---|---|
| POST | `/auth/register`, `/auth/login` | Registro (siempre rol cliente) y login. Rate limit 10/min |
| POST | `/auth/logout` · GET `/me` | Sesión |
| GET | `/zones` | Barrios con cobertura |
| GET/POST/PUT/DELETE | `/addresses` | Direcciones con pin; el pin debe caer dentro del barrio |
| GET | `/restaurants?category=`, `/restaurants/categories`, `/restaurants/{id}` | Catálogo y menú |
| GET/POST | `/orders` · GET `/orders/{id}`, `/orders/{id}/route` | Pedidos y ruta simulada |
| GET | `/driver/orders` · POST `/driver/orders/{id}/advance`, `/driver/orders/{id}/deliver` | Repartidor. `deliver` exige el código (máx. 5 intentos/min) |
| POST | `/demo/orders/{id}/advance` | Solo con `APP_DEMO=true`: avanza estados sin cambiar de cuenta |

## 2. App Flutter

### En Chrome
```bash
cd app
flutter pub get
flutter run -d chrome
```

### APK para el celular
El celular y el computador deben estar en la **misma red WiFi**. El backend debe correr con `--host=0.0.0.0`.

```bash
ipconfig getifaddr en0          # IP del Mac, ej. 192.168.0.108
flutter build apk --release --dart-define=API_BASE_URL=http://192.168.0.108:8000/api
```

El APK queda en `app/build/app/outputs/flutter-apk/app-release.apk`. Pásalo al celular e instálalo; hay que permitir "instalar apps desconocidas".

**Si la IP del Mac cambia** (otra red WiFi), no hace falta recompilar. En el login toca **"Servidor: …"** y escribe `http://NUEVA_IP:8000/api`. Si la red de la universidad bloquea la conexión entre dispositivos, comparte internet desde el celular y conecta el Mac a ese hotspot.

## 3. Desplegar el backend (para que la app conecte siempre a la misma URL)

En vez de depender de la IP local, el backend puede vivir en **Render** (gratis) con la base de datos en **Neon** (PostgreSQL gratis, sin expirar por inactividad). El repo ya trae `Dockerfile`, `render.yaml` y el script de deploy en `backend/`.

1. **Crear la base de datos en [neon.tech](https://neon.tech)** (cuenta gratis, sin tarjeta): crear un proyecto, copiar el *connection string* (`postgresql://usuario:password@host/basededatos?sslmode=require`).
2. **Generar la `APP_KEY`** localmente: `cd backend && php artisan key:generate --show` (copiar el valor `base64:...`).
3. **Crear el servicio en [render.com](https://render.com)** (cuenta gratis): "New" → "Blueprint" → conectar este repo de GitHub. Render detecta `render.yaml` automáticamente.
4. Al desplegar, Render pedirá los valores marcados `sync: false` en `render.yaml`: pegar ahí la `APP_KEY` del paso 2 y los datos de conexión de Neon (`DB_HOST`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD` — se sacan del connection string del paso 1).
5. Primer deploy: el build corre `composer install`, cachea config/rutas y ejecuta `php artisan migrate --force`. Para sembrar los datos demo una sola vez, abrir la "Shell" del servicio en Render y correr `php artisan db:seed`.
6. Render entrega una URL fija, ej. `https://domiquibdo-backend.onrender.com`. Usarla en la app:
   ```bash
   flutter run -d chrome --dart-define=API_BASE_URL=https://domiquibdo-backend.onrender.com/api
   flutter build apk --release --dart-define=API_BASE_URL=https://domiquibdo-backend.onrender.com/api
   ```
   También se puede pegar esa URL en el login, en **"Servidor: …"**, sin recompilar.

**Nota:** el plan free de Render "duerme" el backend tras 15 min sin tráfico; la primera petición después de eso tarda ~1 min en responder. Es normal, solo hay que esperar el primer request antes de empezar la demo.

## Guion de demo sugerido
1. **Login** con el chip "Cliente".
2. **Catálogo**: skeletons de carga, filtro por categoría, transición Hero a un restaurante.
3. **Carrito → Confirmar pedido**. Agregar una dirección: el pin debe quedar dentro del barrio; fuera de la zona no deja guardar.
4. En el **detalle del pedido** aparece el **código de 4 dígitos**. Con "Modo demo" se pasa a *confirmado → preparando → en camino* y se abre el mapa.
5. **Tracking**: el marcador avanza cada ~3.5 s. Probar **SOS** (llamada simulada) y **Compartir por WhatsApp**.
6. En el celular (o cerrando sesión), entrar como **repartidor**:
   - un código incorrecto se rechaza
   - con el correcto el pedido pasa a *entregado*
   - el cliente ve la confirmación automáticamente
7. **Perfil → Apariencia → Oscuro** para mostrar el dark mode.

## Decisiones de seguridad (Sprint 0)
- El **rol nunca viene del request**: el registro público solo crea clientes.
- El **total lo calcula el servidor** desde la BD. Los precios enviados por el cliente se ignoran.
- El **código de verificación** solo se serializa para el cliente dueño del pedido, nunca para el repartidor. Se compara con `hash_equals` y tiene límite de 5 intentos por minuto.
- `OrderPolicy`: un cliente no puede ver pedidos ajenos; el repartidor solo gestiona pedidos libres o asignados a él.
- Las direcciones se restringen a **zonas de cobertura** validadas en el servidor (distancia haversine).
- El token se guarda en `flutter_secure_storage`.

## Notas sobre los datos
- Nombres, direcciones y teléfonos de los restaurantes provienen de fuentes públicas.
- **Las coordenadas son aproximadas**, ubicadas a partir de la dirección.
- **Menús y precios son inventados** para el proyecto y no representan la oferta real de cada negocio.
- Los centros y radios de los barrios también son aproximados.
- Las portadas se generan por categoría (degradado + ícono), para no usar fotos sin permiso.
- Mapas: © colaboradores de OpenStreetMap.

## Roadmap (entrega de noviembre)
- **GPS real** con `geolocator` en background (foreground service, permisos de Android 14). `delivery_mock_route` se reemplaza por posiciones en vivo sin cambiar `orders`.
- **Laravel Reverb** (WebSockets) para tracking y estados en vivo; hoy la app hace polling cada 4-8 s.
- **PostGIS**: polígonos reales de barrios (`ST_Contains`) y búsqueda de "restaurantes a menos de X km".
- Pasarela de pagos, panel administrativo, app separada para repartidores y verificación de identidad.
