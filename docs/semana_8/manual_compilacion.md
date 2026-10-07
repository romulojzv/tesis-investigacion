# Manual de Compilación Determinista — Cuentos Mágicos (Flutter Windows)

**Proyecto:** Cuentos Mágicos (Tesis de Investigación)  
**Plataforma de Ejecución:** Windows 10/11 x64  
**Fecha de Verificación:** Octubre 2026  
**Documento:** `docs/semana_8/manual_compilacion.md`

---

## 1. Introducción y Concepto de Compilación

Este manual describe el proceso exacto y secuencial para compilar la aplicación de escritorio **Cuentos Mágicos** para Windows.

### Compilación Reproducible vs. Binarios Idénticos Byte a Byte
- **Compilación Reproducible (Garantizada):** El proyecto fija las versiones exactas de las librerías Dart a través de `pubspec.lock` y las dependencias de scripts mediante `package-lock.json`. Cualquier desarrollador que compile el código con el toolchain especificado obtendrá el mismo comportamiento funcional, idéntica compatibilidad de APIs y ausencia de desvíos en tiempo de ejecución.
- **Binarios Idénticos Byte a Byte (Puntualización Técnica):** Los compiladores de C++ de Microsoft (`cl.exe` y `link.exe`) incrustan por defecto marcas de tiempo (timestamps) en los encabezados PE/COFF, paths locales en los metadatos PDB y firmas dinámicas en los binarios compilados (`tesis_investigacion.exe`). Por lo tanto, dos compilaciones generadas en momentos distintos diferirán en sus hashes criptográficos (SHA-256) aunque su código fuente y comportamiento sean idénticos, a menos que se configure explícitamente el flag `/Brepro` de MSVC.

---

## 2. Toolchain y Versiones Reales Verificadas

Todas las versiones indicadas en esta tabla han sido constatadas y verificadas directamente en el entorno de desarrollo:

| Herramienta / Componente | Versión Exacta Verificada | Comando de Verificación |
| :--- | :--- | :--- |
| **Sistema Operativo** | Microsoft Windows 11 Pro (Build 26100.0, x64) | `[System.Environment]::OSVersion.VersionString` |
| **Flutter SDK** | `3.47.6` (channel stable, revision `5fc346839b`) | `flutter --version` |
| **Dart SDK** | `3.13.5` (DevTools `2.60.0`) | `dart --version` |
| **Visual Studio Community** | `2026` (Dev18, Versión `18.10.3` / `18.10.12224.181`) | `vswhere.exe -latest` |
| **MSVC C++ Build Tools** | Toolset `v14.51.36231` (x86/x64) | `Get-ChildItem ".../VC/Tools/MSVC"` |
| **Windows SDK** | `10.0.26100.0` | Instalado con Visual Studio C++ Workload |
| **CMake (Bundled con VS)** | `4.3.1-msvc1` | `cmake --version` (ruta interna VS) |
| **Ninja (Bundled con VS)** | `1.13.2` | `ninja --version` (ruta interna VS) |
| **NuGet CLI** | `7.9.0.83` | `nuget help` |
| **Node.js** | `v24.21.0` | `node --version` |
| **npm** | `11.19.0` | `npm.cmd --version` |
| **Supabase CLI** | `2.119.0` | `npx.cmd supabase --version` |

---

## 3. Prerrequisitos de Instalación

Antes de iniciar la compilación en una máquina limpia:

1. **Instalar Visual Studio Community 2026** (o Build Tools 2026) seleccionando la carga de trabajo:
   - *"Desarrollo para el escritorio con C++"* (*Desktop development with C++*).
   - Componentes incluidos obligatorios: MSVC v143/v144/v145 x64/x86 build tools, Windows 10/11 SDK, C++ CMake tools for Windows.
2. **Instalar Flutter SDK 3.47.6:**
   - Descomprimir en una ruta sin espacios ni caracteres especiales (ej. `C:\flutter`).
   - Agregar `C:\flutter\bin` a la variable de entorno `PATH`.
3. **Instalar Node.js v24 LTS:**
   - Permite ejecutar la suite de scripts de automatización e invocación de Edge Functions.

---

## 4. Guía Paso a Paso de Compilación

Todos los comandos deben ejecutarse en una consola **PowerShell** abierta en la raíz del proyecto.

### Paso 1: Clonar el Repositorio
```powershell
git clone https://github.com/tu-organizacion/tesis_investigacion.git
cd tesis_investigacion
```

### Paso 2: Verificar el Toolchain del Sistema
Ejecutar el diagnóstico oficial de Flutter:
```powershell
flutter doctor -v
```
**Resultado esperado:** Las secciones *"Flutter"*, *"Windows Version"* y *"Visual Studio - develop for Windows"* deben mostrar un check verde (`[✓]`).

### Paso 3: Configurar Variables de Entorno de Supabase
La aplicación requiere las credenciales públicas de Supabase para inicializarse.

> [!CAUTION]
> **REGLA DE SEGURIDAD:** Únicamente se configura la clave anónima pública (`anon_key`). **NUNCA** incrustar la clave `service_role` ni contraseñas en el código fuente de Flutter ni en binarios cliente.

Crear o verificar el archivo `.env` en la raíz (o pasar variables vía `--dart-define`):
```ini
SUPABASE_URL=https://wdehfetiazgukfgnngfi.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

En tiempo de compilación con Flutter, también se pueden inyectar mediante:
```powershell
$DART_DEFINES = "--dart-define=SUPABASE_URL=https://wdehfetiazgukfgnngfi.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJI..."
```

### Paso 4: Restaurar Dependencias Bloqueadas
Utilizar el archivo `pubspec.lock` para garantizar la descarga de las versiones exactas:
```powershell
flutter pub get
```
Para los scripts auxiliares de TypeScript:
```powershell
npm.cmd ci
```
*(o `npm.cmd install` si `node_modules` no existe)*.

### Paso 5: Verificación de Formato y Análisis Estático
Validar que no existan errores de sintaxis, variables sin usar ni advertencias del linter:
```powershell
# Comprobar formato sin alterar archivos
dart format --output=none --set-exit-if-changed .

# Análisis estático riguroso
flutter analyze
```
**Resultado esperado:** `No issues found!` (0 errores, 0 advertencias).

### Paso 6: Ejecución de la Suite de Pruebas Automatizadas
Verificar que los 134 tests unitarios y de widgets pasen exitosamente:
```powershell
flutter test
```
**Resultado esperado:** `All tests passed!` (134 tests superados).

### Paso 7: Compilación del Ejecutable de Windows

#### Opción A: Modo Debug (Para inspección y depuración)
```powershell
flutter build windows --debug
```
- **Ruta del ejecutable generado:**  
  `build\windows\x64\runner\Debug\tesis_investigacion.exe`
- **Tiempo típico de compilación:** ~25 - 40 segundos en hardware estándar.

#### Opción B: Modo Release (Para distribución y producción)
```powershell
flutter build windows --release
```
- **Ruta del ejecutable generado:**  
  `build\windows\x64\runner\Release\tesis_investigacion.exe`
- **Características del binario Release:** Optimizaciones de compilador C++ `/O2`, árboles de código de Dart recortados (Tree-shaking) y máxima velocidad de renderizado en motor Impeller/Skia.

---

## 5. Estructura del Paquete de Distribución

El ejecutable `tesis_investigacion.exe` no es un binario autónomo; depende de las bibliotecas dinámicas del motor Flutter y plugins nativos. La carpeta de distribución contiene:

```text
build\windows\x64\runner\Release\
├── tesis_investigacion.exe          # Ejecutable principal
├── flutter_windows.dll             # Motor de Flutter para Windows
├── data\                           # Assets empaquetados, fuentes y blobs
│   ├── icudtl.dat                  # Internacionalización y Unicode
│   └── flutter_assets\             # Fuentes, imágenes y manifiestos de la app
├── file_picker_windows_plugin.dll  # Plugin nativo para selección de archivos PDF
└── flutter_tts_plugin.dll          # Plugin nativo para síntesis de voz (SAPI)
```

---

## 6. Validación de Funcionamiento del Binario

Para validar que el binario compila y ejecuta correctamente sin dependencias del IDE:

```powershell
# Ejecutar directamente el binario generado
& ".\build\windows\x64\runner\Debug\tesis_investigacion.exe"
```

### Comprobaciones Mínimas en la UI
1. **Inicio y AuthGate:** La pantalla muestra la interfaz de bienvenida de Cuentos Mágicos con pestañas *"Estudiante"* y *"Docente"*.
2. **Normalización:** Al escribir un código de acceso de estudiante (ej. `SMK1`), las letras se transforman a mayúsculas automáticamente.
3. **Persistencia:** Si existe una sesión previa válida de Supabase, la app transiciona directamente a `StudentHomeView` o `TeacherHomeView`.
4. **Cierre de Sesión:** El botón de *"Cerrar sesión"* finaliza la sesión localmente y retorna al login.
