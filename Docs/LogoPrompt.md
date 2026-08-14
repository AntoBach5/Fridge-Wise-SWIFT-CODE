# Prompt para generar el logo de Fridge Wise

Copia el bloque de abajo tal cual y pégalo en Midjourney, DALL·E, Ideogram o
cualquier generador de imágenes. Debajo hay variantes y notas de uso.

---

## Prompt principal

```
App icon for "Fridge Wise", an iOS recipe app that photographs your fridge and
tells you what to cook.

CONCEPT: a single continuous line forming a fridge silhouette whose interior
negative space reads as a leaf. One idea, two readings — appliance and produce.
Nothing else in the frame.

STYLE: warm editorial minimalism. Hand-drawn confidence, not geometric
perfection: the stroke has slight weight variation, like ink from a fine brush
pen. Think Kinfolk magazine, Aesop packaging, mid-century Scandinavian kitchen
posters. NOT a tech startup logo, NOT a glossy 3D app icon, NOT gradient mesh.

COLOR — use these exact values, no others:
- Background: warm bone paper #F4F1E9 (never pure white)
- Line: deep charcoal with a green undertone #23282B (never pure black)
- One accent only, on a single small detail: sage green #8BA482

COMPOSITION: centered, generous margins, the mark occupying about 60% of the
canvas. Flat vector. No drop shadows, no bevels, no glow, no outline frame.
Subtle paper grain texture at very low opacity is welcome.

MOOD: calm, domestic, trustworthy, a little handmade. The feeling of a good
cookbook, not of software.

FORMAT: square 1:1, flat 2D vector illustration, solid background.
```

---

## Variantes por si la primera no convence

Sustituye el bloque `CONCEPT:` por uno de estos y deja todo lo demás igual:

**A — Sartén y hoja**
```
CONCEPT: a top-down skillet drawn in one continuous line, where the handle
curves around and becomes the stem of a leaf resting inside the pan.
```

**B — La abstracción de la nevera**
```
CONCEPT: two stacked rounded rectangles suggesting a fridge door and freezer,
with the dividing line extended past the edges like a horizon. A single small
sage-green dot sits where the handle would be.
```

**C — Monograma**
```
CONCEPT: the letters F and W merged into a single mark, where the crossbar of
the F extends to become the middle stroke of the W, and the whole shape reads
as a simplified fridge seen from the front.
```

**D — La pista sensorial**
```
CONCEPT: a minimal bowl seen from the side with three short curved strokes
rising from it like steam, the middle stroke ending in a small leaf.
```

---

## Por qué el prompt dice lo que dice

**Los colores están fijados a mano.** Si dejas que el modelo elija, saldrá azul
o degradado naranja-rosa: es el promedio de los logos de app que ha visto. Los
tres hex del prompt son exactamente los tokens `Palette.canvas`, `Palette.ink` y
`Palette.sage` de la app, así que el icono cuadra con la primera pantalla en vez
de pelearse con ella.

**Un solo acento.** La app tiene siete colores de acento, pero un icono con siete
colores a 60×60 px es una mancha. El resto de la paleta ya vive dentro.

**Nada de blanco puro ni negro puro.** Es la regla que sostiene todo el diseño de
la app; un icono con `#FFFFFF` detrás se nota como pieza ajena en cuanto se abre.

**"Hand-drawn confidence, not geometric perfection".** Sin esa frase salen formas
de compás, y el lenguaje visual de la app se apoya en trazos dibujados a mano
(el squiggle bajo los titulares, el tilde de las casillas).

**Se nombran referencias, no adjetivos.** "Minimalista" no significa nada para un
generador. Kinfolk y Aesop sí.

---

## Qué pedir después

1. **Prueba a 60 px antes de decidir.** Reduce el resultado al tamaño real de un
   icono en la pantalla de inicio. Si el concepto se pierde, es demasiado
   detallado — pide "simplify, fewer strokes, thicker line".
2. **Pide el SVG o vectoriza.** Lo que salga es un PNG. Para App Store Connect
   hace falta 1024×1024 nítido y sin transparencia.
3. **Variante oscura.** Repite el prompt cambiando fondo a `#14140F` y línea a
   `#F2EFE5`. iOS 18 permite iconos en modo oscuro y teñidos.
4. **Sin texto.** Si el generador cuela la palabra "Fridge Wise" dentro del
   icono, quítala: los iconos de iOS no llevan el nombre, ya lo pone el sistema
   debajo.

Cuando lo tengas, reemplaza el placeholder de
`FridgeWise/Assets.xcassets/AppIcon.appiconset/`.
