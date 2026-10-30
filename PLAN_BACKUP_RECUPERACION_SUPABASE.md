# PLAN DE RESPALDO Y RECUPERACIÓN ANTE DESASTRES — SUPABASE
**Proyecto de Tesis:** Cuentos Mágicos — Aplicación Educativa Adaptativa  
**Enfoque:** Protección de la Información de Investigación, Resiliencia y Recuperación  
**Fecha:** 30 de octubre de 2026  
**Responsable:** Ingeniero Senior de Base de Datos y Recuperación ante Desastres  

---

## 1. Estado Actual de Respaldos del Proyecto

### 1.1. Respaldo Existente Identificado
En la inspección del repositorio se verificó la existencia de una copia de seguridad lógica estructurada:
- **Ubicación:** `backups/backup_habitual_2026-10-15T04-40-16-985Z.json`
- **Fecha de Generación:** 15 de octubre de 2026 (04:40:12 UTC)
- **Tablas Respaldadas:** 8 tablas (`aulas`, `aula_estudiantes`, `profiles`, `cuentos`, `escenas`, `decisiones_narrativas`, `quiz_intentos`, `quiz_respuestas`).
- **Registros Contenidos:** 23 escenas completas, 8 cuentos base del piloto, 3 intentos de cuestionario.
- **Herramienta Empleada:** Script oficial `scripts/backup_habitual.cjs`.

---

## 2. Estrategia de Exportación de Datos en el Plan Free

Debido a que el plan gratuito de Supabase no incluye copias de seguridad automáticas diarias descargables desde la interfaz gráfica, se establecen dos métodos de respaldo lógico reproducibles:

### Método A: Exportación Relacional Completa mediante Supabase CLI
Permite extraer tanto el DDL (tablas, RLS, funciones, triggers) como los datos en formato SQL estándar compatible con cualquier motor PostgreSQL 17+:

#### 1. Exportar Esquema y Políticas (Estructura y RLS)
```powershell
npx supabase db dump --project-ref wdehfetiazgukfgnngfi -s public,app_private -f backups/schema_backup_$(Get-Date -Format "yyyyMMdd").sql
```

#### 2. Exportar Registros de Datos (Data-Only)
```powershell
npx supabase db dump --project-ref wdehfetiazgukfgnngfi --data-only --use-copy -f backups/data_backup_$(Get-Date -Format "yyyyMMdd").sql
```

### Método B: Exportación Estructurada en JSON (Vía Node.js / PostgREST)
Para auditorías rápidas y trazabilidad documental de la tesis, se utiliza el script preconfigurado en el repositorio:
```powershell
node scripts/backup_habitual.cjs
```
Este comando consulta las 8 tablas esenciales y genera un archivo consolidado `backups/backup_habitual_<timestamp>.json`.

---

## 3. Respaldo de Archivos Multimedia (Supabase Storage)

Si la plataforma almacena ilustraciones o dibujos generados en el bucket `cuentos`:

### 3.1. Procedimiento de Descarga de Objetos
Para descargar los archivos almacenados en la nube hacia una carpeta local segura:
```powershell
npx supabase storage cp -r ss:///cuentos ./backups/storage_cuentos --project-ref wdehfetiazgukfgnngfi --experimental
```
*Si el bucket aún no ha sido poblado porque las imágenes se gestionan temporalmente mediante URLs de servicios generativos, este paso se ejecuta una vez que se habilite la persistencia de Storage.*

---

## 4. Protocolos de Recuperación ante Incidentes

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        ÁRBOL DE DECISIÓN DE RECUPERACIÓN OPERACIONAL                   │
└───────────────────────────────────────────┬────────────────────────────────────────────┘
                                            │
               ┌────────────────────────────┴────────────────────────────┐
               ▼                                                         ▼
┌──────────────────────────────┐                         ┌──────────────────────────────┐
│ ESCENARIO A: PROYECTO        │                         │ ESCENARIO B: SERVICIO ACTIVO │
│ PAUSADO POR INACTIVIDAD      │                         │ PERO NO RESPONDE (HTTP 500)  │
├──────────────────────────────┤                         ├──────────────────────────────┤
│ 1. Ir a Dashboard Supabase   │                         │ 1. Verificar estado de API   │
│ 2. Clic en "Restore project" │                         │ 2. Ejecutar db inspect       │
│ 3. Esperar 2-5 minutos       │                         │ 3. Reiniciar servicios Supabase│
└──────────────────────────────┘                         └──────────────────────────────┘
               │                                                         │
               └────────────────────────────┬────────────────────────────┘
                                            ▼
                         ┌──────────────────────────────────────┐
                         │ ESCENARIO C: PÉRDIDA TOTAL O         │
                         │ CORRUPCIÓN DE ENTORNO                │
                         ├──────────────────────────────────────┤
                         │ 1. Crear nuevo proyecto o usar local │
                         │ 2. Aplicar las 3 migraciones canónicas│
                         │ 3. Restaurar datos desde dump SQL    │
                         └──────────────────────────────────────┘
```

### Protocolo 1: Restauración de un Proyecto Pausado
1. Acceder al navegador e ingresar a:
   `https://supabase.com/dashboard/project/wdehfetiazgukfgnngfi`
2. El panel mostrará la notificación de proyecto pausado.
3. Presionar el botón **"Restore project"**.
4. Supabase aprovisionará nuevamente la máquina virtual en AWS `us-east-1` y montará el volumen de almacenamiento existente sin pérdida de información.
5. Comprobar la conexión ejecutando en la terminal local:
   ```powershell
   npx supabase inspect db table-stats --project-ref wdehfetiazgukfgnngfi
   ```

### Protocolo 2: Proyecto Activo pero Sin Respuesta (Timeout o PostgREST Caído)
1. Comprobar si el incidente se debe a la red local o a la infraestructura de Supabase consultando `https://status.supabase.com`.
2. Ejecutar un reinicio del subsistema PostgREST desde el Dashboard:
   - Ir a **Project Settings > General Infrastructure > Restart Database**.
3. Verificar si el problema reside en una consulta bloqueada ejecutando:
   ```powershell
   npx supabase inspect db blocking --project-ref wdehfetiazgukfgnngfi
   ```

### Protocolo 3: Recuperación ante Pérdida Total o Migración a Nueva Instancia
Si se requiriese recrear la base de datos completa desde cero en un nuevo proyecto:
1. Crear un proyecto limpio en Supabase o inicializar el stack local con `npx supabase start`.
2. Vincular el proyecto con `npx supabase link --project-ref <nuevo-ref>`.
3. Desplegar de forma idéntica las 3 migraciones canónicas:
   ```powershell
   npx supabase db push
   ```
4. Restaurar los datos desde el último archivo de volcado:
   ```powershell
   psql -h <nuevo-host> -U postgres -d postgres -f backups/data_backup_20261015.sql
   ```
5. Desplegar las 7 Edge Functions canónicas:
   ```powershell
   npx supabase functions deploy --all
   ```

---

## 5. Salvaguardas Éticas y Privacidad de Datos Escolares

1. **Confidencialidad de Menores:** Los archivos de respaldo generados en `backups/` contienen información sensible de estudiantes del piloto (códigos de acceso, calificaciones, perfiles).
2. **Exclusión de Git:** La carpeta `backups/` debe permanecer estrictamente listada en `.gitignore` para evitar su publicación accidental en repositorios de GitHub públicos o privados.
3. **Cifrado en Reposo:** Las copias de respaldo locales deben almacenarse en discos protegidos mediante **BitLocker** en Windows o cifrarse con contraseñas seguras antes de cualquier traslado físico.
4. **Cero Restauraciones Automáticas Invasivas:** Queda prohibido ejecutar comandos como `supabase db reset` contra el proyecto vinculado remoto `wdehfetiazgukfgnngfi` sin autorización formal previa.
