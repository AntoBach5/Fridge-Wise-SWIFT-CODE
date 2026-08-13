# Fridge Wise

App iOS en SwiftUI. Sacas una foto de la nevera, te dice qué tienes, y te propone
qué cocinar con eso.

---

## Abrir el proyecto

```bash
open FridgeWise.xcodeproj
```

Requiere **Xcode 16 o superior** (el proyecto usa grupos sincronizados con el sistema
de archivos: añades un `.swift` a la carpeta y entra solo al target, sin conflictos de
merge en `project.pbxproj`). Deployment target: **iOS 17.0**.

Al abrir, Xcode resuelve solo los tres paquetes SPM. Si tienes Xcode 15 o quieres
regenerar el proyecto desde cero:

```bash
brew install xcodegen && xcodegen generate
```

### Probar las compras sin App Store Connect

En el esquema → *Run* → *Options* → **StoreKit Configuration**, elige
`FridgeWise/Products.storekit`. Ya trae los cuatro packs de puntos y las dos
suscripciones con prueba gratis de una semana.

---

## Estructura

```
FridgeWise/
├── App/                  AppEnvironment (estado raíz), RootView, punto de entrada
├── DesignSystem/         Paleta, tipografía, métricas, motion, hápticos, formas
│   └── Components/       Superficies, botones, dataviz, controles, estados
├── Bridges/              Adaptadores a FluidGradient · Rive · Introspect
├── Navigation/           Tab bar pill flotante y rutas
├── Models/               Dominio + datos de muestra
├── Services/             Escáner, IA, puntos, StoreKit, ads, moderación, ATT
└── Features/
    ├── Kitchen/          Pantalla principal
    ├── Scan/             Cámara, análisis, revisión de detecciones
    ├── Recipes/          Feed, detalle, generación con IA, modo cocina
    ├── Community/        Comentarios, valoraciones, reportes, normas
    ├── Lists/            To Buy · To Cook
    ├── Rewards/          Puntos, canjes, tienda de packs
    ├── Paywall/          Premium y límites del plan gratuito
    └── Settings/         Ajustes, bloqueados, datos y privacidad
```

**Una sola fuente de verdad.** Todo lo que cambia el mundo pasa por
`AppEnvironment`: sumar a una lista, guardar una receta, publicar un comentario,
consumir cuota. Las vistas nunca mutan colecciones por su cuenta, así el metering,
los puntos y la persistencia no se pueden "olvidar" en una pantalla nueva.

---

## El lenguaje visual

Se llama **Warm Pantry** y sale de la referencia *Warm Reflection*.

| | |
|---|---|
| **Lienzo** | Papel hueso cálido `#F4F1E9`, nunca blanco puro. Grano procedural al 3,5%. |
| **Tinta** | Carbón verdoso `#23282B` para texto, pill del tab bar y botones primarios. |
| **Acentos** | Derivados de produce real: tomate, arcilla, salvia, albahaca, cúrcuma, ciruela, niebla. Desaturados: son marcadores semánticos, no decoración. |
| **Titulares** | New York (serif del sistema), regular y grande. La jerarquía la da el tamaño y el tracking, no el peso. |
| **UI** | SF Pro. Micro-labels en versalitas con tracking de 1,35. |
| **Firma** | Squiggle dibujado a mano bajo la palabra en cursiva del titular. Una vez por pantalla, nunca dos. |
| **Radios** | Siempre `.continuous`. Las esquinas circulares se ven de Android. |
| **Motion** | Springs nombrados en `Motion`. Nada rebota dos veces. |

Reglas que se aplican en todo el código:

- **Cero azul de sistema.** No hay un solo `Color.blue` ni `.tint` por defecto.
- **Cero `List`, `Form`, `Picker`, `Toggle` o `Stepper` nativos.** Todos traen
  geometría y grises de iOS que rompen el papel. Están reimplementados.
- **Ningún número mágico.** Todo espaciado sale de `Space`, todo radio de `Radius`.
- **Nada anima sin respetar Reducir movimiento** — está en `.motion(_:value:)`.

---

## Las tres librerías

Cada una entra por un **puente** con `#if canImport`. Eso significa que el proyecto
compila y corre aunque SPM no haya resuelto todavía, y que si una librería se rompe
en una versión futura de iOS la app sigue andando con el fallback nativo.

| Librería | Dónde se usa | Fallback |
|---|---|---|
| [**FluidGradient**](https://github.com/Cindori/FluidGradient) | Hero de la Cocina, tarjeta de escaneo, paywall, celebración de puntos, estados vacíos | Blobs a la deriva dibujados en `Canvas` |
| [**RiveRuntime**](https://github.com/rive-app/rive-ios) | Escáner analizando, chef pensando, confeti de recompensa, racha | SF Symbols con `.symbolEffect` |
| [**SwiftUIIntrospect**](https://github.com/siteline/swiftui-introspect) | `keyboardDismissMode`, rubber-band de carruseles, desaceleración editorial, matar separadores nativos | No-op (`self`) |

Las animaciones de Rive están catalogadas como casos de `RiveAsset`, con el nombre de
archivo, la state machine y los inputs documentados. Todavía no hay ningún `.riv` en el
bundle — la app usa los fallbacks. Cuando lleguen del diseñador de motion, se sueltan
en `Resources` y aparecen solas.

> **Nota de versión sobre Introspect:** los modifiers apuntan a `.iOS(.v17, .v18)`.
> Si SPM resuelve una versión que todavía no conoce `.v18`, saca ese caso de las listas
> en `Bridges/IntrospectBridge.swift`.

---

## Qué está mockeado

Lo dejamos así a propósito, como pediste: el reconocimiento de imagen va después.
Lo que **ya está fijo es el contrato**, así la UI no se reescribe cuando llegue el
modelo real.

| Servicio | Estado | Qué falta |
|---|---|---|
| `FridgeScanning` | `MockFridgeScanner` | Enchufar Vision + un modelo de detección, o un endpoint propio. Ya emite fases, confianza por ítem y cajas de detección. |
| `RecipeGenerating` | `MockRecipeGenerator` | Enchufar el modelo. Ya emite fases de progreso y respeta exclusiones dietarias como filtro duro. |
| `AdProviding` | `HouseAdProvider` | Enchufar AdMob u otra red. Las **reglas** ya están y no las decide el SDK. |
| Backend de moderación | Filtro local | El filtro del cliente da feedback instantáneo; la decisión final va en el servidor. |

La **cámara sí es real** (`AVFoundation`, con detección de poca luz, tap-to-focus y
manejo completo de permisos). En el simulador cae a un fondo animado y el flujo de
escaneo corre igual, así se puede diseñar sin dispositivo.

---

## Antes de publicar

Ver [`Docs/AppStoreCompliance.md`](Docs/AppStoreCompliance.md) — la checklist completa
de lo que ya está implementado y lo que hay que completar fuera del código
(App Store Connect, URLs legales, nutrition labels).

Los tres bloqueantes reales:

1. **Publicar las URLs legales.** `Services/ModerationService.swift` → `SupportContact`
   apunta a `fridgewise.app/terminos`, `/privacidad` y `/normas-comunidad`. Tienen que
   existir y responder, o es rechazo automático.
2. **Cargar los productos en App Store Connect** con los mismos IDs que
   `PointPack.catalog` y `PremiumProduct`.
3. **Decidir si va a haber publicidad personalizada.** Si no, poner
   `NSPrivacyTracking` en `<false/>` dentro de `PrivacyInfo.xcprivacy` y sacar el
   prompt de ATT: pedir permiso de tracking sin usarlo es rechazo.

---

## Decisiones que vale la pena conocer

**El escaneo es teatral a propósito.** Las fases ("recorriendo los estantes" →
"identificando ingredientes") y los pins que aparecen uno a uno sobre tu propia foto
no están para disimular latencia. Están porque un spinner de tres segundos seguido de
una lista se siente como magia barata, y ver los pins caer sobre tu nevera se siente
como que algo entendió lo que hay adentro.

**Toda detección pasa por revisión humana.** Nada entra a la despensa sin que el
usuario lo confirme, y lo que tiene menos de 75% de confianza sube arriba de todo en
ámbar. Una despensa con datos mal cargados envenena todas las recetas que vengan
después.

**El plan gratuito es usable, no una demo.** Los límites se muestran *antes* de que el
usuario invierta esfuerzo, nunca después de que sacó la foto. Y cuando se acaban, hay
tres salidas y dos son gratis.

**Cero anuncios donde molestan.** `AdCoordinator` bloquea publicidad durante el
escaneo y el modo cocina. Interrumpir a alguien con las manos llenas de harina saca
reseñas de una estrella mucho antes que ingresos.

**La gamificación acompaña, no persigue.** Sin cuentas regresivas, sin "perdés tu racha
en 2 horas", sin ruletas. La visita diaria acredita una vez por día natural, no por
sesión.
