// scripts/test_validar_preguntas_deno.ts
import { assertEquals } from "jsr:@std/assert";
import { validarEstructuraPreguntas } from "../supabase/functions/generar-quiz/index.ts";

Deno.test("RF-22: Valida distribución exacta 2 literal, 2 inferencial, 1 critico_reflexivo", () => {
  const preguntasValidas = [
    {
      numero: 1,
      pregunta: "¿Cómo se llamaba el protagonista?",
      opciones: ["Ana", "Pedro", "Lucas", "Tomás"],
      indiceCorrecto: 0,
      explicacion: "El cuento dice explícitamente que se llamaba Ana.",
      nivelComprension: "literal",
    },
    {
      numero: 2,
      pregunta: "¿Qué objeto encontró en el camino?",
      opciones: ["Una llave", "Una espada", "Un mapa", "Una flor"],
      indiceCorrecto: 2,
      explicacion: "Encontró un mapa antiguo en el suelo.",
      nivelComprension: "literal",
    },
    {
      numero: 3,
      pregunta: "¿Por qué el dragón estaba triste?",
      opciones: ["Perdió su cueva", "No tenía amigos", "Tenía frío", "Le dolía un ala"],
      indiceCorrecto: 1,
      explicacion: "Las pistas indican que se sentía solo en la montaña.",
      nivelComprension: "inferencial",
    },
    {
      numero: 4,
      pregunta: "¿Qué consecuencia tuvo ayudar a la ardilla?",
      opciones: ["Le dio nueces", "Le mostró el atajo", "Se fue corriendo", "Llamó a otros animales"],
      indiceCorrecto: 1,
      explicacion: "Gracias a su ayuda, la ardilla le guió por el atajo del bosque.",
      nivelComprension: "inferencial",
    },
    {
      numero: 5,
      pregunta: "¿Cuál fue la decisión más prudente de Ana?",
      opciones: ["Cruzar el río con cuidado", "Correr sin mirar", "Ignorar las señales", "Dejar su mochila"],
      indiceCorrecto: 0,
      explicacion: "Cruzar con cuidado evitó el peligro y permitió llegar a salvo.",
      nivelComprension: "critico_reflexivo",
    },
  ];

  const resultado = validarEstructuraPreguntas(preguntasValidas);
  assertEquals(resultado !== null, true);
  assertEquals(resultado?.length, 5);
  assertEquals(resultado?.[0].nivelComprension, "literal");
  assertEquals(resultado?.[1].nivelComprension, "literal");
  assertEquals(resultado?.[2].nivelComprension, "inferencial");
  assertEquals(resultado?.[3].nivelComprension, "inferencial");
  assertEquals(resultado?.[4].nivelComprension, "critico_reflexivo");
});

Deno.test("RF-22: Rechaza si no cumple la distribución exigida", () => {
  const preguntasConDistribucionInvalida = [
    {
      numero: 1,
      pregunta: "¿Cómo se llamaba el protagonista?",
      opciones: ["Ana", "Pedro", "Lucas", "Tomás"],
      indiceCorrecto: 0,
      explicacion: "El cuento dice explícitamente que se llamaba Ana.",
      nivelComprension: "literal",
    },
    {
      numero: 2,
      pregunta: "¿Qué objeto encontró en el camino?",
      opciones: ["Una llave", "Una espada", "Un mapa", "Una flor"],
      indiceCorrecto: 2,
      explicacion: "Encontró un mapa antiguo en el suelo.",
      nivelComprension: "literal",
    },
    {
      numero: 3,
      pregunta: "¿Por qué el dragón estaba triste?",
      opciones: ["Perdió su cueva", "No tenía amigos", "Tenía frío", "Le dolía un ala"],
      indiceCorrecto: 1,
      explicacion: "Las pistas indican que se sentía solo en la montaña.",
      nivelComprension: "literal", // Debería ser inferencial
    },
    {
      numero: 4,
      pregunta: "¿Qué consecuencia tuvo ayudar a la ardilla?",
      opciones: ["Le dio nueces", "Le mostró el atajo", "Se fue corriendo", "Llamó a otros animales"],
      indiceCorrecto: 1,
      explicacion: "Gracias a su ayuda, la ardilla le guió por el atajo del bosque.",
      nivelComprension: "inferencial",
    },
    {
      numero: 5,
      pregunta: "¿Cuál fue la decisión más prudente de Ana?",
      opciones: ["Cruzar el río con cuidado", "Correr sin mirar", "Ignorar las señales", "Dejar su mochila"],
      indiceCorrecto: 0,
      explicacion: "Cruzar con cuidado evitó el peligro y permitió llegar a salvo.",
      nivelComprension: "critico_reflexivo",
    },
  ];

  const resultado = validarEstructuraPreguntas(preguntasConDistribucionInvalida);
  assertEquals(resultado, null);
});
