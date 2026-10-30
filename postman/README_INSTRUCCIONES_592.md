# Guía de Ejecución Rápida: Pruebas de Seguridad EV-UI-19 y EV-UI-20 (Apartado 5.9.2)

## Opción A: Mediante la Consola Visual Web (Recomendada para Capturas Perfectas)

1. Abre el archivo en tu navegador (Edge o Chrome):
   - Ruta local: `file:///c:/Users/edwin/Downloads/tesisisi/avance/tesis_investigacion/postman/herramienta_pruebas_seguridad_tesis_5_9_2.html`
2. **Para EV-UI-19:**
   - Haz clic en la pestaña **"EV-UI-19: Respuesta Cruzada"**.
   - Pulsa el botón **"Ejecutar Solicitud HTTP (EV-UI-19)"**.
   - Presiona **`Windows + Shift + S`** y recorta el recuadro con el estado **403 Forbidden** y el JSON `{ "error": "Intento no autorizado para este estudiante." }`.
3. **Para EV-UI-20:**
   - Haz clic en la pestaña **"EV-UI-20: Inmutabilidad de Respuesta"**.
   - Pulsa el botón **"Ejecutar Solicitud HTTP (EV-UI-20)"**.
   - Presiona **`Windows + Shift + S`** y recorta el recuadro con el estado **409 Conflict** y el JSON `{ "error": "Respuesta ya confirmada y no modificable" }`.

---

## Opción B: Mediante Postman (Colección Oficial)

1. Abre **Postman**.
2. Pulsa en **Import** (esquina superior izquierda) y arrastra los dos archivos ubicados en la carpeta `postman/`:
   - Colección: `Tesis_5.9.2_Pruebas_Seguridad.postman_collection.json`
   - Entorno: `Tesis_5.9.2_Staging.postman_environment.json`
3. En la esquina superior derecha de Postman, selecciona el entorno **"Tesis Staging - Seguridad 5.9.2"**.
4. **Para EV-UI-19:**
   - En la barra lateral, abre la solicitud:
     `EV-UI-19: Intento no autorizado entre estudiantes (HTTP 403 Forbidden)`
   - Pulsa el botón azul **Send**.
   - En la parte inferior observarás el badge **`403 Forbidden`** y el cuerpo `{ "error": "Intento no autorizado para este estudiante." }`.
   - Presiona **`Windows + Shift + S`** para tomar la captura.
5. **Para EV-UI-20:**
   - Abre la solicitud:
     `EV-UI-20: Intento de alteración de respuesta confirmada (HTTP 409 Conflict)`
   - Pulsa el botón azul **Send**.
   - En la parte inferior observarás el badge **`409 Conflict`** y el cuerpo `{ "error": "Respuesta ya confirmada y no modificable" }`.
   - Presiona **`Windows + Shift + S`** para tomar la captura.

---

## Privacidad de Datos y Parámetros
- **Endpoint:** `POST https://acxsyswrzdtstgqztojj.supabase.co/functions/v1/responder-pregunta`
- **Encabezados:** Muestran únicamente `Authorization: Bearer {{token_estudiante_x}}`, manteniendo el JWT enmascarado.
- **Base de Datos:** Verificada como inmutable mediante consultas de solo lectura en PostgreSQL.
