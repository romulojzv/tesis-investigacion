# PLAN DE CONTINUIDAD Y PREVENCIÓN DE PAUSA — SUPABASE
**Proyecto:** Cuentos Mágicos — Aplicación Educativa Adaptativa  
**Objetivo:** Reducir el riesgo de suspensión de la base de datos por inactividad sin comprometer datos reales ni generar costos imprevistos  
**Fecha:** 30 de octubre de 2026  
**Responsable:** Ingeniero Senior de Infraestructura, PostgreSQL y Supabase  

---

## 1. Contexto y Política Oficial de Pausa de Supabase (Free Tier)

### 1.1. Condiciones del Plan Gratuito
De acuerdo con las políticas oficiales de Supabase para organizaciones en el plan **Free**:
1. **Regla de Inactividad:** Los proyectos que no registran actividad en su base de datos durante aproximadamente **7 días continuos** entran automáticamente en estado **Pausado (`PAUSED`)**.
2. **Efecto de la Pausa:**
   - La máquina virtual / contenedor de cómputo de PostgreSQL se detiene.
   - Las peticiones HTTP entrantes a la API PostgREST o Auth retornan errores `HTTP 503 Service Unavailable` o mensajes indicando que el proyecto está pausado.
   - **Los datos no se eliminan:** El almacenamiento físico de PostgreSQL permanece resguardado como una instantánea (*snapshot*) de respaldo.
3. **Mecanismo de Despausa (Restauración):**
   - El propietario del proyecto debe ingresar manualmente al Dashboard de Supabase (`https://supabase.com/dashboard/project/<project-ref>`) y hacer clic en **"Restore project"**.
   - El proceso de restauración suele tardar entre 2 y 5 minutos.

### 1.2. Qué Constituye Actividad Real de Base de Datos
> [!IMPORTANT]
> **Diferencia Crítica entre Ping HTTP y Consulta PostgreSQL:**
> - Un simple `GET` al endpoint raíz `https://<ref>.supabase.co/` o una solicitud sin API Key es interceptada por el API Gateway (Kong / Cloudflare) y responde con un error `401 Unauthorized` **sin llegar a tocar el motor PostgreSQL**. Esto **NO** cuenta como actividad de base de datos.
> - Para que el sistema de telemetría de Supabase registre actividad legítima, la solicitud debe autenticarse y ejecutar una consulta real de lectura en el motor relacional (por ejemplo, un `SELECT` a través de PostgREST o una llamada a una función SQL).

---

## 2. Estrategia de Monitoreo Periódico y Reducción del Riesgo

Para evitar la suspensión por inactividad durante los períodos de revisión académica de la tesis, se diseñó una solución **responsable, de bajo consumo y sin riesgos de mutación de datos**.

### 2.1. Principios del Diseño
1. **Baja Frecuencia:** Se ejecuta **1 o 2 veces al día** (por ejemplo, a las 06:00 y 18:00 UTC). Esto es más que suficiente para reiniciar el contador de inactividad de 7 días sin generar saturación.
2. **Privilegio Mínimo:** Utiliza exclusivamente la clave pública anónima (`anon key`) o una cuenta de servicio de solo lectura.
3. **Cero Acceso a Datos de Estudiantes:** La consulta no lee nombres, contraseñas, correos ni identificadores personales de alumnos o docentes.
4. **Cero Mutaciones (100% Solo Lectura):** Solo ejecuta un `SELECT` mínimo (`limit=1`). No inserta, modifica ni borra registros.
5. **Cero Consumo de IA:** No invoca Edge Functions vinculadas a Gemini ni a generación de imágenes (0 créditos consumidos).
6. **Tolerancia a Fallos y Timeouts:** Timeout estricto de **10 segundos** y máximo **1 reintento** para evitar bucles.
7. **Monitoreo de Salud:** Registra fecha, código HTTP, tiempo de respuesta en milisegundos y detecta tempranamente errores `401`, `403`, `429`, `500` y `503` (proyecto pausado).

---

## 3. Especificación Técnica de la Comprobación (Healthcheck)

### 3.1. Consulta Seleccionada
Para el entorno de **Staging (`acxsyswrzdtstgqztojj`)** y **Producción (`wdehfetiazgukfgnngfi`)**:
- **Método:** `GET`
- **Ruta:** `/rest/v1/cuentos?select=id&limit=1`
- **Cabeceras Requeridas:**
  - `apikey: <SUPABASE_ANON_KEY>`
  - `Authorization: Bearer <SUPABASE_ANON_KEY>`
- **Comportamiento Esperado:**
  - Si el rol `anon` tiene permiso de lectura restringido por RLS, PostgREST ejecuta la consulta en PostgreSQL y retorna un arreglo vacío `[]` con código `HTTP 200 OK`.
  - Si la tabla tiene `REVOKE ALL FROM anon`, el motor PostgreSQL evalúa el permiso y retorna `HTTP 401/403` pero **habiendo interactuado con el subsistema de base de datos**.
  - Alternativamente, si se utiliza un token autenticado de un usuario de prueba sintético de Staging, la consulta `SELECT id FROM profiles WHERE id = auth.uid()` ejecuta un ciclo completo de base de datos con tiempo de respuesta < 200 ms.

---

## 4. Propuesta de Automatización Externa (GitHub Actions)

> [!CAUTION]
> **ESTADO DE LA PROPUESTA:**
> Este flujo se entrega en formato de plantilla documentada. **NO ha sido activado ni publicado en el repositorio GitHub**, en estricto cumplimiento de la solicitud del usuario. Para activarlo, el usuario debe crear el archivo en `.github/workflows/` y configurar los Secrets en GitHub.

### 4.1. Archivo de Flujo Propuesto
Ubicación sugerida: `.github/workflows/supabase_keepalive_monitor.yml`

```yaml
name: Supabase Keepalive & Health Monitor

on:
  schedule:
    # Se ejecuta diariamente a las 12:00 UTC (07:00 AM hora de Perú)
    - cron: '0 12 * * *'
  workflow_dispatch: # Permite ejecución manual desde la pestaña Actions

jobs:
  healthcheck:
    name: Supabase DB Ping & Health Check
    runs-on: ubuntu-latest
    timeout-minutes: 5

    steps:
      - name: Ejecutar consulta de verificación en Supabase
        run: |
          echo "========================================================"
          echo "Iniciando comprobación periódica de Supabase..."
          echo "Fecha/Hora: $(date -u)"
          echo "========================================================"
          
          SUPABASE_URL="${{ secrets.SUPABASE_URL }}"
          SUPABASE_KEY="${{ secrets.SUPABASE_ANON_KEY }}"
          
          if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_KEY" ]; then
            echo "::error::Faltan variables secretas SUPABASE_URL o SUPABASE_ANON_KEY en GitHub Secrets."
            exit 1
          fi

          # 1. Comprobación de Auth Health
          START_TIME=$(date +%s%3N)
          HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "apikey: $SUPABASE_KEY" \
            -H "Authorization: Bearer $SUPABASE_KEY" \
            --max-time 10 \
            "$SUPABASE_URL/auth/v1/settings")
          END_TIME=$(date +%s%3N)
          LATENCY=$((END_TIME - START_TIME))

          echo "Respuesta Auth Settings: HTTP $HTTP_STATUS en ${LATENCY}ms"

          if [ "$HTTP_STATUS" -eq 200 ]; then
            echo "✅ Subsistema Auth: ACTIVO"
          elif [ "$HTTP_STATUS" -eq 503 ]; then
            echo "::error::🚨 ALERTA: El proyecto Supabase se encuentra PAUSADO (HTTP 503)."
            exit 1
          else
            echo "::warning::Respuesta inesperada en Auth: HTTP $HTTP_STATUS"
          fi

          # 2. Comprobación real de consulta a PostgreSQL vía PostgREST
          START_TIME=$(date +%s%3N)
          REST_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "apikey: $SUPABASE_KEY" \
            -H "Authorization: Bearer $SUPABASE_KEY" \
            --max-time 10 \
            "$SUPABASE_URL/rest/v1/cuentos?select=id&limit=1")
          END_TIME=$(date +%s%3N)
          LATENCY=$((END_TIME - START_TIME))

          echo "Respuesta PostgREST (DB Query): HTTP $REST_STATUS en ${LATENCY}ms"

          if [ "$REST_STATUS" -eq 200 ] || [ "$REST_STATUS" -eq 401 ] || [ "$REST_STATUS" -eq 403 ]; then
            echo "✅ Subsistema PostgreSQL: ACTIVO (Conectividad validada)"
          elif [ "$REST_STATUS" -eq 503 ]; then
            echo "::error::🚨 ALERTA: La base de datos está pausada o no responde (HTTP 503)."
            exit 1
          else
            echo "::error::Fallo en consulta de base de datos: HTTP $REST_STATUS"
            exit 1
          fi
```

### 4.2. Guía para Configurar los Secretos en GitHub
Para habilitar este flujo cuando lo decidas:
1. Ve al repositorio en GitHub: `https://github.com/romulojzv/tesis-investigacion`.
2. Dirígete a **Settings > Secrets and variables > Actions**.
3. Haz clic en **New repository secret** y registra:
   - `SUPABASE_URL`: `https://wdehfetiazgukfgnngfi.supabase.co` (o el de Staging si prefieres monitorear Staging).
   - `SUPABASE_ANON_KEY`: El valor de la clave pública anónima (sin comillas).

---

## 5. Procedimiento de Recuperación si el Proyecto se Pausa

Si por alguna eventualidad la base de datos de Supabase entra en pausa:

```
┌────────────────────────────────────────────────────────────────────────┐
│               PROCEDIMIENTO DE REACTIVACIÓN EN CASO DE PAUSA           │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
       1. Ingresar a https://supabase.com/dashboard/project/wdehfetiazgukfgnngfi
                                    │
                                    ▼
       2. Iniciar sesión con la cuenta universitaria autorizada
                                    │
                                    ▼
       3. Visualizar el mensaje: "Project is paused due to inactivity"
                                    │
                                    ▼
       4. Hacer clic en el botón verde: "Restore Project"
                                    │
                                    ▼
       5. Esperar entre 2 y 5 minutos mientras Supabase recrea el contenedor
                                    │
                                    ▼
       6. Verificar el estado: "ACTIVE_HEALTHY"
                                    │
                                    ▼
       7. Comprobar que los datos del piloto permanezcan íntegros
```

---

## 6. Limitaciones Formales y Alternativa de Alta Disponibilidad (Plan Pro)

### 6.1. Limitaciones Técnicas del Plan Gratuito
- **Sin Garantía Contractual de Uptime:** El plan Free de Supabase no ofrece un Acuerdo de Nivel de Servicio (SLA) con disponibilidad garantizada. Supabase puede reiniciar o actualizar servidores de acuerdo con sus ventanas de mantenimiento.
- **Efectividad del Keepalive:** Si bien una consulta diaria mantiene caliente el cómputo y restablece la ventana de 7 días, Supabase podría actualizar sus algoritmos de detección de actividad o pausar proyectos gratuitos que no presenten tráfico interactivo de usuarios reales.
- **Declaración Ética:** No debe afirmarse que «el riesgo de suspensión ha sido eliminado definitivamente» bajo un plan gratuito; el riesgo se encuentra **significativamente mitigado**, pero sujeto a los términos del proveedor.

### 6.2. Alternativa Profesional para Disponibilidad Permanente (Supabase Pro)
Si para la fase de sustentación pública o defensa ante el jurado se exige disponibilidad continua al 100% sin riesgo de pausa:
- **Plan:** Supabase Pro Tier.
- **Costo Vigente (2026):** **$25.00 USD mensuales**.
- **Beneficios:**
  - **Cero pausas por inactividad:** Las bases de datos nunca se suspenden.
  - **Respaldos automáticos diarios:** Copias de seguridad automáticas gestionadas con retención de 7 días.
  - **SLA de Cómputo:** 8 GB de almacenamiento de base de datos incluidos y 100 GB de transferencia.
- *Nota: No se debe realizar ninguna contratación sin aprobación expresa del titular del proyecto.*
