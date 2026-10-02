# Cuentos Mágicos

Cuentos Mágicos es una aplicación educativa desarrollada con Flutter para Windows, orientada al desarrollo de actividades de comprensión lectora mediante narrativa interactiva, retroalimentación y generación dinámica de contenido.

## Tecnologías utilizadas

- Flutter 3.47.6
- Dart 3.13.5
- Windows Desktop
- Supabase
- PostgreSQL
- Gemini API
- Git
- GitHub

## Arquitectura

La aplicación utiliza una arquitectura basada en MVC complementada con las capas Services y Repository.

### View
Contiene las interfaces con las que interactúa el usuario.

### Controller
Coordina las acciones solicitadas desde las interfaces y gestiona el flujo general de la aplicación.

### Model
Representa las principales entidades de la solución.

### Services
Contiene la integración con servicios externos y funcionalidades técnicas.

### Repository
Encapsula las operaciones relacionadas con la persistencia y recuperación de datos.

## Estructura principal

```text
lib/
├── controllers/
├── models/
├── repositories/
├── services/
├── views/
└── main.dart