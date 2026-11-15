# Spacesapps: simulación de un viaje a la Luna

Simulación en 3D, en 8 etapas, de una misión tripulada a la Luna, hecha para NASA Space Apps.
En cada etapa se muestra qué siente el cuerpo de la tripulación y qué hacer.

**Jugar en el navegador:** https://thonyferriel05.github.io/spacesapps/

## Etapas

1. Despegue
2. Separación de la etapa principal
3. Órbita terrestre (la etapa superior sube la órbita y se suelta)
4. Cinturones de Van Allen
5. Rumbo a la Luna
6. Tormenta solar (escenario simulado)
7. Fuga de oxígeno (escenario simulado)
8. Estabilizado junto a la Luna

## Controles

- **Espacio:** pausa
- **Flechas izquierda / derecha:** etapa anterior / siguiente
- **1 a 8:** ir a una etapa
- **H:** ocultar los textos

## Cómo está hecho

- Motor: **Godot 4.7.2**, con el modo de dibujo "Compatibilidad" (el que funciona en navegador)
- Lenguaje: **GDScript**
- `scripts/main.gd`: arma la escena, las cámaras, los efectos y los textos de cada etapa
- `scripts/astronaut.gd`: mueve al astronauta de la cámara de cabina según lo que pasa (fuerza G, radiación, falta de oxígeno)
- `models/`: modelos 3D en formato `.glb` (cohete, cápsula, Tierra, Luna, astronauta)
- `docs/`: la versión web ya exportada (es lo que publica GitHub Pages)

Para abrir el proyecto: instala Godot 4.7.2, abre `project.godot` y presiona F5.
