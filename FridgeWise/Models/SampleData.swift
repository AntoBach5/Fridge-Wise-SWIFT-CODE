//
//  SampleData.swift
//  FridgeWise
//
//  Datos de muestra. No son "lorem ipsum": están escritos con la voz real del
//  producto y con números plausibles, porque un diseño se valida con contenido
//  verdadero. Un layout que se ve bien con "Recipe 1 / Recipe 2" y se rompe con
//  "Guiso de lentejas con calabaza y chorizo colorado" no está terminado.
//

import Foundation

enum SampleData {

    // MARK: - Fechas

    private static func days(_ count: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: count, to: .now) ?? .now
    }

    // MARK: - Ingredientes detectables

    /// Catálogo que usa el escáner mock. Cubre las siete categorías para que
    /// la UI de agrupado se ejercite siempre.
    static let detectableIngredients: [Ingredient] = [
        Ingredient(name: "Huevos", category: .protein, quantity: "8 unidades", expiresAt: days(12)),
        Ingredient(name: "Espinaca", category: .produce, quantity: "1 manojo", expiresAt: days(2)),
        Ingredient(name: "Tomates cherry", category: .produce, quantity: "250 g", expiresAt: days(4)),
        Ingredient(name: "Queso parmesano", category: .dairy, quantity: "180 g", expiresAt: days(28)),
        Ingredient(name: "Yogur natural", category: .dairy, quantity: "500 g", expiresAt: days(1)),
        Ingredient(name: "Pechuga de pollo", category: .protein, quantity: "600 g", expiresAt: days(2)),
        Ingredient(name: "Arroz integral", category: .grains, quantity: "1 kg", expiresAt: days(240)),
        Ingredient(name: "Pasta integral", category: .grains, quantity: "500 g", expiresAt: days(180)),
        Ingredient(name: "Cebolla morada", category: .produce, quantity: "3 unidades", expiresAt: days(18)),
        Ingredient(name: "Ajo", category: .produce, quantity: "1 cabeza", expiresAt: days(30)),
        Ingredient(name: "Limón", category: .produce, quantity: "4 unidades", expiresAt: days(9)),
        Ingredient(name: "Mantequilla", category: .dairy, quantity: "200 g", expiresAt: days(35)),
        Ingredient(name: "Aceite de oliva", category: .condiments, quantity: "750 ml", expiresAt: days(400)),
        Ingredient(name: "Mostaza Dijon", category: .condiments, quantity: "1 frasco", expiresAt: days(150)),
        Ingredient(name: "Guisantes congelados", category: .frozen, quantity: "400 g", expiresAt: days(120)),
        Ingredient(name: "Salmón congelado", category: .frozen, quantity: "2 filetes", expiresAt: days(60)),
        Ingredient(name: "Guiso de lentejas", category: .leftovers, quantity: "2 porciones", expiresAt: days(1)),
        Ingredient(name: "Zanahorias", category: .produce, quantity: "5 unidades", expiresAt: days(14)),
        Ingredient(name: "Garbanzos", category: .grains, quantity: "1 lata", expiresAt: days(300)),
        Ingredient(name: "Leche", category: .dairy, quantity: "1 L", expiresAt: days(3))
    ]

    /// Despensa inicial para la primera corrida.
    static var pantry: [Ingredient] {
        Array(detectableIngredients.prefix(11))
    }

    // MARK: - Autores

    static let authors: [CommunityAuthor] = [
        CommunityAuthor(displayName: "Malena R.", initials: "MR", accent: .tomato,
                        isVerifiedCook: true, recipesPublished: 34),
        CommunityAuthor(displayName: "Tomás Iriarte", initials: "TI", accent: .sage,
                        recipesPublished: 8),
        CommunityAuthor(displayName: "Cocina de Ana", initials: "CA", accent: .turmeric,
                        isVerifiedCook: true, recipesPublished: 121),
        CommunityAuthor(displayName: "Nico V.", initials: "NV", accent: .mist, recipesPublished: 3),
        CommunityAuthor(displayName: "Paula G.", initials: "PG", accent: .plum, recipesPublished: 17)
    ]

    // MARK: - Recetas

    static let recipes: [Recipe] = [
        Recipe(
            title: "Frittata de espinaca y parmesano",
            subtitle: "Usa la espinaca que vence en dos días",
            source: .generated,
            minutes: 22, difficulty: 1, calories: 340, servings: 2,
            grade: .a,
            macros: Macros(proteinGrams: 24, carbGrams: 9, fatGrams: 23, fiberGrams: 3),
            ingredients: [
                RecipeIngredient(name: "Huevos", amount: "6", category: .protein, isInPantry: true),
                RecipeIngredient(name: "Espinaca", amount: "1 manojo", category: .produce, isInPantry: true),
                RecipeIngredient(name: "Queso parmesano", amount: "60 g", category: .dairy, isInPantry: true),
                RecipeIngredient(name: "Cebolla morada", amount: "1/2", category: .produce, isInPantry: true),
                RecipeIngredient(name: "Aceite de oliva", amount: "2 cdas", category: .condiments, isInPantry: true),
                RecipeIngredient(name: "Nuez moscada", amount: "1 pizca", category: .condiments, isInPantry: false, isOptional: true)
            ],
            steps: [
                RecipeStep(order: 1, instruction: "Calienta el horno a 180 °C. Saltea la cebolla en aceite de oliva hasta que esté translúcida.", minutes: 5),
                RecipeStep(order: 2, instruction: "Suma la espinaca y cocina hasta que pierda el agua. Escurre bien.", minutes: 4,
                           tip: "Si queda agua, la frittata sale húmeda por dentro."),
                RecipeStep(order: 3, instruction: "Bate los huevos con la mitad del parmesano, sal y pimienta. Mezcla con la verdura.", minutes: 3),
                RecipeStep(order: 4, instruction: "Vuelca en una sartén de hierro y cocina a fuego bajo 4 minutos, hasta que los bordes cuajen.", minutes: 4),
                RecipeStep(order: 5, instruction: "Termina en el horno 6 minutos con el resto del parmesano encima.", minutes: 6,
                           tip: "El centro tiene que quedar apenas tembloroso: sigue cocinándose fuera del horno.")
            ],
            tags: [.quick, .veggie, .highProtein, .useSoon, .onePan],
            allergens: ["Huevo", "Lácteos"],
            accent: .sage,
            imageName: nil,
            rating: 4.7, ratingCount: 218, savedCount: 1_940,
            authorName: nil, authorInitials: nil
        ),

        Recipe(
            title: "Pollo al limón con arroz integral",
            subtitle: "Una sola sartén, treinta y cinco minutos",
            source: .generated,
            minutes: 35, difficulty: 2, calories: 520, servings: 2,
            grade: .b,
            macros: Macros(proteinGrams: 42, carbGrams: 48, fatGrams: 16, fiberGrams: 5),
            ingredients: [
                RecipeIngredient(name: "Pechuga de pollo", amount: "600 g", category: .protein, isInPantry: true),
                RecipeIngredient(name: "Arroz integral", amount: "180 g", category: .grains, isInPantry: true),
                RecipeIngredient(name: "Limón", amount: "2", category: .produce, isInPantry: true),
                RecipeIngredient(name: "Ajo", amount: "3 dientes", category: .produce, isInPantry: true),
                RecipeIngredient(name: "Mostaza Dijon", amount: "1 cda", category: .condiments, isInPantry: true),
                RecipeIngredient(name: "Caldo de verduras", amount: "400 ml", category: .condiments, isInPantry: false),
                RecipeIngredient(name: "Perejil", amount: "1 puñado", category: .produce, isInPantry: false)
            ],
            steps: [
                RecipeStep(order: 1, instruction: "Salpimenta el pollo y séllalo 4 minutos de cada lado. Resérvalo.", minutes: 8),
                RecipeStep(order: 2, instruction: "En la misma sartén, dora el ajo y suma el arroz. Nacaralo un minuto.", minutes: 3),
                RecipeStep(order: 3, instruction: "Añade el caldo, el zumo de un limón y la mostaza. Lleva a hervor.", minutes: 3),
                RecipeStep(order: 4, instruction: "Vuelve el pollo a la sartén, tapa y cocina a fuego bajo 18 minutos.", minutes: 18,
                           tip: "No destapes: el arroz integral necesita el vapor."),
                RecipeStep(order: 5, instruction: "Reposa 3 minutos y termina con ralladura de limón y perejil.", minutes: 3)
            ],
            tags: [.highProtein, .onePan, .budget],
            allergens: ["Mostaza"],
            accent: .turmeric,
            imageName: nil,
            rating: 4.5, ratingCount: 96, savedCount: 780,
            authorName: nil, authorInitials: nil
        ),

        Recipe(
            title: "Ensalada tibia de garbanzos y zanahoria asada",
            subtitle: "Ligera, económica y aguanta dos días",
            source: .editorial,
            minutes: 28, difficulty: 1, calories: 380, servings: 2,
            grade: .a,
            macros: Macros(proteinGrams: 15, carbGrams: 46, fatGrams: 14, fiberGrams: 12),
            ingredients: [
                RecipeIngredient(name: "Garbanzos", amount: "1 lata", category: .grains, isInPantry: true),
                RecipeIngredient(name: "Zanahorias", amount: "4", category: .produce, isInPantry: true),
                RecipeIngredient(name: "Yogur natural", amount: "4 cdas", category: .dairy, isInPantry: true),
                RecipeIngredient(name: "Limón", amount: "1", category: .produce, isInPantry: true),
                RecipeIngredient(name: "Comino", amount: "1 cdta", category: .condiments, isInPantry: false),
                RecipeIngredient(name: "Menta fresca", amount: "1 puñado", category: .produce, isInPantry: false, isOptional: true)
            ],
            steps: [
                RecipeStep(order: 1, instruction: "Horno a 200 °C. Corta las zanahorias en bastones gruesos.", minutes: 4),
                RecipeStep(order: 2, instruction: "Mezcla zanahorias y garbanzos escurridos con aceite, comino y sal. Asa 20 minutos.", minutes: 20,
                           tip: "Seca bien los garbanzos con papel: así quedan crocantes en vez de blandos."),
                RecipeStep(order: 3, instruction: "Bate el yogur con zumo de limón y sal para el aderezo.", minutes: 2),
                RecipeStep(order: 4, instruction: "Sirve tibio, con el aderezo por encima y menta si tienes.", minutes: 2)
            ],
            tags: [.veggie, .lowCal, .budget, .quick],
            allergens: ["Lácteos"],
            accent: .clay,
            imageName: nil,
            rating: 4.8, ratingCount: 341, savedCount: 2_610,
            authorName: nil, authorInitials: nil
        ),

        Recipe(
            title: "Salmón con guisantes a la mantequilla",
            subtitle: "De congelador a mesa en veinte minutos",
            source: .community,
            minutes: 20, difficulty: 2, calories: 465, servings: 2,
            grade: .b,
            macros: Macros(proteinGrams: 38, carbGrams: 18, fatGrams: 26, fiberGrams: 6),
            ingredients: [
                RecipeIngredient(name: "Salmón congelado", amount: "2 filetes", category: .frozen, isInPantry: true),
                RecipeIngredient(name: "Guisantes congelados", amount: "300 g", category: .frozen, isInPantry: true),
                RecipeIngredient(name: "Mantequilla", amount: "40 g", category: .dairy, isInPantry: true),
                RecipeIngredient(name: "Limón", amount: "1", category: .produce, isInPantry: true),
                RecipeIngredient(name: "Eneldo", amount: "1 puñado", category: .produce, isInPantry: false, isOptional: true)
            ],
            steps: [
                RecipeStep(order: 1, instruction: "Descongela el salmón en la nevera o bajo agua fría corriente. Sécalo bien.", minutes: 5,
                           tip: "Nunca lo descongeles a temperatura ambiente."),
                RecipeStep(order: 2, instruction: "Sella el salmón con la piel hacia abajo 5 minutos sin moverlo.", minutes: 5),
                RecipeStep(order: 3, instruction: "Dale la vuelta 2 minutos y reserva. Saltea los guisantes en la mantequilla.", minutes: 5),
                RecipeStep(order: 4, instruction: "Termina con zumo de limón y sirve el salmón sobre los guisantes.", minutes: 3)
            ],
            tags: [.quick, .highProtein, .onePan],
            allergens: ["Pescado", "Lácteos"],
            accent: .mist,
            imageName: nil,
            rating: 4.4, ratingCount: 58, savedCount: 410,
            authorName: "Malena R.", authorInitials: "MR"
        ),

        Recipe(
            title: "Pasta cremosa de tomates cherry",
            subtitle: "Reconfortante sin crema, solo con el almidón",
            source: .community,
            minutes: 25, difficulty: 1, calories: 560, servings: 2,
            grade: .c,
            macros: Macros(proteinGrams: 18, carbGrams: 78, fatGrams: 18, fiberGrams: 7),
            ingredients: [
                RecipeIngredient(name: "Pasta integral", amount: "220 g", category: .grains, isInPantry: true),
                RecipeIngredient(name: "Tomates cherry", amount: "250 g", category: .produce, isInPantry: true),
                RecipeIngredient(name: "Ajo", amount: "3 dientes", category: .produce, isInPantry: true),
                RecipeIngredient(name: "Queso parmesano", amount: "50 g", category: .dairy, isInPantry: true),
                RecipeIngredient(name: "Albahaca", amount: "1 puñado", category: .produce, isInPantry: false)
            ],
            steps: [
                RecipeStep(order: 1, instruction: "Pon a hervir agua con bastante sal y cocina la pasta.", minutes: 10),
                RecipeStep(order: 2, instruction: "Mientras, revienta los tomates en una sartén con ajo y aceite.", minutes: 8),
                RecipeStep(order: 3, instruction: "Suma un cucharón del agua de cocción y el parmesano fuera del fuego.", minutes: 3,
                           tip: "El almidón del agua es lo que emulsiona: sin eso la salsa se corta."),
                RecipeStep(order: 4, instruction: "Mezcla la pasta con la salsa y termina con albahaca.", minutes: 2)
            ],
            tags: [.veggie, .comfort, .budget, .quick],
            allergens: ["Gluten", "Lácteos"],
            accent: .tomato,
            imageName: nil,
            rating: 4.6, ratingCount: 187, savedCount: 1_320,
            authorName: "Cocina de Ana", authorInitials: "CA"
        )
    ]

    /// El generador mock reordena el catálogo según qué tiene el usuario y
    /// qué está por vencer, y recalcula `isInPantry` contra la despensa real.
    static func generatedRecipes(for pantry: [Ingredient]) -> [Recipe] {
        let pantryNames = Set(pantry.map { $0.name.lowercased() })
        let expiringNames = Set(
            pantry.filter { $0.freshness >= .useSoon }.map { $0.name.lowercased() }
        )

        return recipes
            .map { recipe in
                var updated = recipe
                updated.id = UUID()
                updated.ingredients = recipe.ingredients.map { ingredient in
                    var copy = ingredient
                    copy.id = UUID()
                    copy.isInPantry = pantryNames.contains(ingredient.name.lowercased())
                    return copy
                }
                if updated.ingredients.contains(where: { expiringNames.contains($0.name.lowercased()) }),
                   !updated.tags.contains(.useSoon) {
                    updated.tags.append(.useSoon)
                }
                return updated
            }
            .sorted { lhs, rhs in
                // Primero lo que rescata comida que vence, después mejor match de despensa.
                let lhsRescues = lhs.tags.contains(.useSoon)
                let rhsRescues = rhs.tags.contains(.useSoon)
                if lhsRescues != rhsRescues { return lhsRescues }
                return lhs.pantryMatch > rhs.pantryMatch
            }
    }

    // MARK: - Comentarios

    static func reviews(for recipeID: Recipe.ID) -> [Review] {
        [
            Review(recipeID: recipeID, author: authors[0], rating: 5,
                   body: "La hice tal cual y salió perfecta. El truco de escurrir bien la espinaca hace toda la diferencia — la primera vez no lo hice y quedó aguada.",
                   createdAt: days(-2), helpfulCount: 24, hasPhoto: true),
            Review(recipeID: recipeID, author: authors[2], rating: 4,
                   body: "Muy buena base. Le sumé pimiento asado y un poco de requesón, y rindió para tres.",
                   createdAt: days(-5), helpfulCount: 11,
                   variationNote: "Con pimiento y requesón"),
            Review(recipeID: recipeID, author: authors[3], rating: 5,
                   body: "Me salvó una cena de último momento con lo que tenía. Veinte minutos reales, no exagera.",
                   createdAt: days(-9), helpfulCount: 7),
            Review(recipeID: recipeID, author: authors[4], rating: 3,
                   body: "Rica pero me quedó sosa. La próxima le pongo el doble de queso y más pimienta.",
                   createdAt: days(-14), helpfulCount: 3)
        ]
    }

    // MARK: - Listas

    static var listItems: [ListItem] {
        [
            ListItem(kind: .toBuy, title: "Caldo de verduras", detail: "400 ml",
                     category: .condiments, recipeTitle: "Pollo al limón con arroz integral"),
            ListItem(kind: .toBuy, title: "Perejil", detail: "1 manojo", category: .produce,
                     recipeTitle: "Pollo al limón con arroz integral"),
            ListItem(kind: .toBuy, title: "Comino", detail: "1 frasco", category: .condiments,
                     recipeTitle: "Ensalada tibia de garbanzos"),
            ListItem(kind: .toBuy, title: "Albahaca fresca", detail: "1 planta", category: .produce),
            ListItem(kind: .toBuy, title: "Pan de masa madre", detail: "1 hogaza", category: .grains),
            ListItem(kind: .toCook, title: "Frittata de espinaca y parmesano",
                     detail: "22 min · Usa la espinaca que vence", plannedFor: .now),
            ListItem(kind: .toCook, title: "Pollo al limón con arroz integral",
                     detail: "35 min · 2 porciones", plannedFor: days(1)),
            ListItem(kind: .toCook, title: "Ensalada tibia de garbanzos",
                     detail: "28 min · aguanta dos días")
        ]
    }

    // MARK: - Catálogo de canjes

    static let rewards: [Reward] = [
        Reward(kind: .adFreeDay,
               title: String(localized: "Un día sin anuncios"),
               detail: String(localized: "24 horas de navegación limpia, desde el momento del canje."),
               cost: 250, icon: "eye.slash", accent: .plum,
               durationHours: 24, isFeatured: true),
        Reward(kind: .extraScans,
               title: String(localized: "5 escaneos extra"),
               detail: String(localized: "Se suman a tu límite diario y no expiran."),
               cost: 180, icon: "viewfinder", accent: .mist, durationHours: nil),
        Reward(kind: .extraGenerations,
               title: String(localized: "10 recetas con IA"),
               detail: String(localized: "Generaciones adicionales para cuando quieres explorar."),
               cost: 300, icon: "sparkles", accent: .turmeric, durationHours: nil),
        Reward(kind: .chefMode,
               title: String(localized: "Modo Chef"),
               detail: String(localized: "Pasos a pantalla completa, temporizadores encadenados y pantalla siempre activa. Para siempre."),
               cost: 1_200, icon: "flame", accent: .tomato, durationHours: nil),
        Reward(kind: .collection,
               title: String(localized: "Colección de estación"),
               detail: String(localized: "40 recetas curadas del trimestre, tuyas para siempre."),
               cost: 900, icon: "books.vertical", accent: .sage, durationHours: nil),
        Reward(kind: .premiumTrial,
               title: String(localized: "7 días de Premium"),
               detail: String(localized: "Prueba todo sin límites una semana. No se renueva ni pide tarjeta."),
               cost: 2_000, icon: "crown", accent: .clay,
               durationHours: 24 * 7, isFeatured: true)
    ]

    // MARK: - Historial de puntos

    static var pointsHistory: [PointsEntry] {
        [
            PointsEntry(event: .recipeCooked, amount: 25, date: days(0),
                        note: "Frittata de espinaca y parmesano"),
            PointsEntry(event: .dailyOpen, amount: 5, date: days(0)),
            PointsEntry(event: .reviewPosted, amount: 20, date: days(-1),
                        note: "Pasta cremosa de tomates cherry"),
            PointsEntry(event: .scanCompleted, amount: 10, date: days(-1)),
            PointsEntry(event: .reviewFoundHelpful, amount: 8, date: days(-2)),
            PointsEntry(event: .streakMilestone, amount: 75, date: days(-3),
                        note: "7 días seguidos"),
            PointsEntry(event: .scanCompleted, amount: 10, date: days(-3)),
            PointsEntry(event: .recipeCooked, amount: 25, date: days(-4),
                        note: "Salmón con guisantes a la mantequilla"),
            PointsEntry(event: .pantryTidied, amount: 6, date: days(-5)),
            PointsEntry(event: .dailyOpen, amount: 5, date: days(-6))
        ]
    }

    static var profile: UserProfile {
        UserProfile(
            displayName: "Alex",
            initials: "AL",
            accent: .sage,
            plan: .free,
            lifetimePoints: 1_340,
            pointsBalance: 465,
            streak: CookStreak(currentDays: 9, bestDays: 23, lastActiveDay: .now)
        )
    }
}
