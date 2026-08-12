import Foundation

/// The coarse daily read that most days should use. Macros exist for the weeks
/// the owner wants them, not as the default unit of account.
public enum DayEatingRating: String, Codable, CaseIterable, Sendable {
    case ateWell
    case okay
    case offPlan

    public var displayName: String {
        switch self {
        case .ateWell: return "Ate well"
        case .okay: return "Okay"
        case .offPlan: return "Off plan"
        }
    }

    /// Deliberately neutral copy — "off plan" is information, not a verdict.
    public var caption: String {
        switch self {
        case .ateWell: return "Food supported the week."
        case .okay: return "Fine. Nothing to fix."
        case .offPlan: return "Noted, and it costs nothing long term."
        }
    }
}

public struct Macros: Codable, Hashable, Sendable {
    public var proteinGrams: Double?
    public var carbGrams: Double?
    public var fatGrams: Double?
    public var calories: Double?

    public init(
        proteinGrams: Double? = nil,
        carbGrams: Double? = nil,
        fatGrams: Double? = nil,
        calories: Double? = nil
    ) {
        self.proteinGrams = proteinGrams
        self.carbGrams = carbGrams
        self.fatGrams = fatGrams
        self.calories = calories
    }
}

public struct NutritionEntry: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var date: Date
    public var rating: DayEatingRating?
    public var macros: Macros?
    /// Local file name inside the app's private photo directory. Never a URL —
    /// photos do not leave the device unless the owner exports them.
    public var photoFileName: String?
    public var note: String
    public var mealTemplateID: UUID?

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        rating: DayEatingRating? = nil,
        macros: Macros? = nil,
        photoFileName: String? = nil,
        note: String = "",
        mealTemplateID: UUID? = nil
    ) {
        self.id = id
        self.date = date
        self.rating = rating
        self.macros = macros
        self.photoFileName = photoFileName
        self.note = note
        self.mealTemplateID = mealTemplateID
    }
}

/// A meal the owner actually eats, in the form they actually think about it —
/// "dal, rice, curd, salad" beats "142g cooked lentils".
public struct MealTemplate: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var components: [String]
    public var macros: Macros?
    public var tags: [String]
    public var note: String

    public init(
        id: UUID = UUID(),
        name: String,
        components: [String] = [],
        macros: Macros? = nil,
        tags: [String] = [],
        note: String = ""
    ) {
        self.id = id
        self.name = name
        self.components = components
        self.macros = macros
        self.tags = tags
        self.note = note
    }
}
