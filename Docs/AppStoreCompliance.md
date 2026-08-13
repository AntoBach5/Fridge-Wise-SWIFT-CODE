# Checklist de App Store — Fridge Wise

Estado de cumplimiento de las guidelines que aplican a esta app.
`✅` implementado en el código · `⚠️` requiere acción fuera del código antes de subir.

Fridge Wise activa cuatro áreas de riesgo a la vez: **contenido generado por usuarios**,
**compras dentro de la app**, **publicidad** y **contenido generado por IA sobre comida**.
Cada una tiene rechazos típicos y aquí está cómo se evitan.

---

## 1.2 — Contenido generado por usuarios

Es el motivo de rechazo más común en apps con comentarios. Apple pide **cuatro** cosas
y las revisa una por una.

| Requisito | Estado | Dónde |
|---|---|---|
| Filtro de contenido objetable antes de publicar | ✅ | `ModerationService.screen(_:)` — corre *mientras* se escribe, no al enviar |
| Mecanismo para reportar contenido | ✅ | `ReportSheet` — accesible en dos toques desde cualquier comentario, sin pedir cuenta |
| Mecanismo para bloquear usuarios abusivos | ✅ | `ModerationService.block(_:)`, menú contextual + `BlockedUsersView` |
| Datos de contacto publicados | ✅ | `SupportContact` — visible en Ajustes y en la hoja de reporte |
| EULA aceptado antes de participar | ✅ | `CommunityAgreementSheet`, versionado en `CommunityAgreement` |
| Respuesta a reportes en plazo razonable | ⚠️ | El compromiso publicado es **24 h**. Hay que tener a alguien que efectivamente modere. |

**Extra propio del dominio:** el filtro incluye patrones de *consejo alimentario
peligroso* (pollo poco cocido, descongelar al sol, recongelar carne, conservas sin
esterilizar). Es el riesgo específico de una app de recetas y no lo cubre ningún filtro
de insultos genérico.

**Antes de subir:**
- Cargar la lista real de términos bloqueados en el backend (`hardBlockTerms` es un placeholder).
- Publicar `fridgewise.app/normas-comunidad`.
- Clasificación por edad: con UGC abierto, esperar **12+ como mínimo**. Declarar
  "contenido generado por usuarios, infrecuente/leve" en el cuestionario.

---

## 3.1.1 — Compras dentro de la app y moneda virtual

| Requisito | Estado | Dónde |
|---|---|---|
| Todo se cobra por IAP, sin pagos externos | ✅ | `StoreService` — no hay un solo link a pagar por fuera |
| Puntos = consumible, no transferibles ni convertibles en dinero | ✅ | Declarado en `RewardsView.fineprint` |
| Se informa si los puntos expiran | ✅ | No expiran, y se dice explícitamente |
| Los consumibles se entregan antes de `finish()` | ✅ | `StoreService.deliver(_:)` |
| Transacciones recuperadas fuera del flujo de compra | ✅ | `Transaction.updates` escuchado desde `init` |
| Los canjes solo dan contenido digital dentro de la app | ✅ | `RewardKind` — sin bienes físicos, sorteos ni dinero |

---

## 3.1.2 — Suscripciones

Cada punto de esta lista se ve en `PaywallView`. Falta uno = rechazo.

- ✅ Título y descripción de qué incluye
- ✅ Duración del período (mensual / anual)
- ✅ Precio desde `Product.displayPrice` — **nunca hardcodeado**
- ✅ Precio por unidad para comparar (equivalente mensual del anual)
- ✅ Declaración de renovación automática y cómo cancelar (`StoreService.renewalDisclosure`)
- ✅ Enlace funcional a Términos de uso (EULA)
- ✅ Enlace funcional a Política de privacidad
- ✅ Botón "Restaurar compras", también en Ajustes
- ✅ Se puede cerrar sin comprar, sin trucos ni "x" escondida
- ✅ Gestión de suscripción vía `.manageSubscriptionsSheet`

⚠️ Los mismos textos legales tienen que aparecer también en la **descripción de la app
en App Store Connect** y en el campo de EULA. No alcanza con tenerlos solo en la app.

---

## 3.2.2 — Nada de azar

- ✅ Sin loot boxes, sin ruletas, sin recompensas aleatorias.
- ✅ Todo canje muestra el costo exacto y lo que entrega, por adelantado.

---

## 5.1.1 — Privacidad

| Requisito | Estado | Dónde |
|---|---|---|
| Textos de permiso que explican el uso real | ✅ | `INFOPLIST_KEY_NS*UsageDescription` en el proyecto |
| Privacy Manifest | ✅ | `PrivacyInfo.xcprivacy` |
| Borrado de cuenta y datos desde adentro de la app (5.1.1 v) | ✅ | `DataPrivacyView` → `AppEnvironment.deleteAllData()` |
| Exportación de datos (GDPR/CCPA) | ✅ | `PersistenceStore.exportAll()` |
| No se condiciona funcionalidad al consentimiento de tracking | ✅ | ATT solo cambia si el anuncio es personalizado |

⚠️ **El manifiesto tiene que coincidir exactamente con las nutrition labels** que
cargues en App Store Connect. Si no coinciden, rechazo.

⚠️ Si finalmente **no** vas a mostrar publicidad personalizada: pon `NSPrivacyTracking`
en `<false/>`, saca los bloques de *Advertising Data* y *Device ID*, y elimina el prompt
de ATT. Pedir permiso de tracking sin usarlo también es motivo de rechazo.

---

## Publicidad — 2.3.1 y 4.x

| Regla | Estado | Dónde |
|---|---|---|
| Anuncios rotulados y distinguibles del contenido | ✅ | `NativeAdCard` — fondo hundido y borde punteado |
| Sin anuncios durante tareas críticas | ✅ | `AdCoordinator.ProtectedContext` — escaneo y modo cocina |
| Sin intersticial al abrir la app | ✅ | Solo en transiciones naturales, con tope de 8 minutos |
| Cero anuncios para Premium o con canje activo | ✅ | `AdCoordinator.adsDisabled` |
| Sin personalización sin ATT | ✅ | `AdCoordinator.personalizationAllowed` |

---

## 1.4.1 — Seguridad física (específico de comida)

Esta es la que se subestima en una app de recetas.

- ✅ Toda receta generada por IA se marca como tal (`SourceBadge`).
- ✅ Los valores nutricionales se declaran **estimaciones**, no datos verificados.
- ✅ Los alérgenos se muestran en el detalle con aviso de que la lista puede estar
  incompleta.
- ✅ Se aclara que no reemplaza el consejo de un profesional de la nutrición.
- ✅ El filtro de moderación marca consejos de seguridad alimentaria riesgosos.

⚠️ Si en algún momento se añaden afirmaciones de salud ("baja de peso", "apto
diabéticos"), la app pasa a categoría de salud y cambia todo el análisis regulatorio.
Evitarlo salvo decisión explícita con asesoría.

---

## 4.7 — Contenido generado por IA

- ✅ El contenido de IA pasa por el mismo filtro de moderación que el de usuarios.
- ✅ Es reportable igual que un comentario.
- ✅ Está etiquetado como generado, nunca presentado como curado por humanos.

---

## Accesibilidad

No es una guideline de rechazo, pero es la mitad de lo que separa una app buena de una
premiada.

- ✅ Dynamic Type en todo el texto (nada de tamaños fijos en `Text`)
- ✅ "Reducir movimiento" respetado en todas las animaciones, vía `.motion(_:value:)`
- ✅ Áreas táctiles de 44pt garantizadas aunque el glifo se vea más chico
- ✅ Etiquetas de VoiceOver en prosa para cada gráfico (`accessibilityValue`)
- ✅ `.isSelected` en todos los controles de selección custom
- ✅ Elementos decorativos marcados `accessibilityHidden`
- ⚠️ Falta auditoría de contraste con texto ampliado al máximo, en dispositivo.

---

## Antes de pulsar "Submit"

1. ⚠️ Publicar y verificar las tres URLs de `SupportContact`.
2. ⚠️ Crear los 6 productos en App Store Connect con los IDs exactos de
   `PointPack.catalog` y `PremiumProduct`.
3. ⚠️ Completar nutrition labels que coincidan con `PrivacyInfo.xcprivacy`.
4. ⚠️ Definir clasificación por edad contemplando el UGC.
5. ⚠️ Preparar cuenta de demo y notas para el revisor explicando el flujo de escaneo
   (el revisor no tiene una nevera a mano: dejarle una foto de prueba en el dispositivo
   o un modo demo).
6. ⚠️ Probar el flujo completo de compra con Sandbox, incluyendo "Ask to Buy" y
   restauración.
7. ⚠️ Reemplazar el ícono placeholder de `AppIcon.appiconset`.
