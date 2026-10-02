# Algoritmo de continuidad narrativa

## 1. Objetivo

El algoritmo de continuidad narrativa tiene como finalidad construir el contexto necesario para generar la siguiente escena de un cuento interactivo a partir de las escenas previamente desarrolladas y de la decisión seleccionada por el estudiante.

La lógica no consiste únicamente en enviar una solicitud a un modelo generativo, sino en organizar el contexto narrativo, mantener la secuencia de escenas, incorporar la elección realizada por el estudiante y añadir restricciones relacionadas con la finalidad educativa de Cuentos Mágicos.

## 2. Entradas

El algoritmo recibe como entradas:

- Lista de escenas previamente generadas.
- Número o posición de cada escena.
- Contenido narrativo de cada escena.
- Decisión seleccionada por el estudiante.
- Parámetros o restricciones utilizados para orientar la continuación del cuento.

## 3. Salida

La salida corresponde al contexto narrativo construido, el cual podrá ser utilizado posteriormente por el servicio de inteligencia artificial generativa para producir una nueva escena.

## 4. Formalización

Sea:

- \(E = \{e_1, e_2, ..., e_n\}\): conjunto de escenas generadas.
- \(D_t\): decisión seleccionada por el estudiante en el instante \(t\).
- \(P\): conjunto de parámetros y restricciones de generación.
- \(C_t\): contexto narrativo acumulado.

El contexto para la generación de la siguiente escena puede expresarse como:

\[
C_t = O(E) + D_t + P
\]

donde:

- \(O(E)\) representa las escenas ordenadas según su secuencia.
- \(D_t\) representa la decisión seleccionada por el estudiante.
- \(P\) representa las instrucciones y restricciones utilizadas para orientar la generación.

La nueva escena podrá expresarse posteriormente como:

\[
e_{n+1} = G(C_t)
\]

donde \(G\) representa el servicio generativo utilizado por la aplicación.

## 5. Pseudocódigo

```text
ALGORITMO ConstruirContextoNarrativo

ENTRADAS:
    escenas
    decisionSeleccionada
    parametrosGeneracion

SALIDA:
    contextoNarrativo

1. Copiar la lista de escenas.
2. Ordenar las escenas según su número.
3. Crear una estructura vacía para almacenar el contexto.
4. Para cada escena ordenada:
       Agregar el número de escena.
       Agregar el contenido narrativo.
5. Agregar la decisión seleccionada por el estudiante.
6. Agregar los parámetros y restricciones de generación.
7. Retornar el contexto narrativo construido.

FIN ALGORITMO