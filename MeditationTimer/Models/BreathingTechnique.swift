import Foundation

struct BreathingTechnique: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var description: String
    var inhale: Double
    var holdIn: Double
    var exhale: Double
    var holdOut: Double
    var isPurchasable: Bool = true

    static let defaultTechnique = BreathingTechnique(
        id: "default",
        name: "Standard",
        description: "A balanced 4-second rhythm for general relaxation.",
        inhale: 4.0,
        holdIn: 0.0,
        exhale: 4.0,
        holdOut: 0.0,
        isPurchasable: false
    )

    static let presets: [BreathingTechnique] = [
        BreathingTechnique(
            id: "box",
            name: "Box Breathing",
            description: "Used by Navy SEALs to stay calm under pressure. Equal parts inhale, hold, exhale, hold.",
            inhale: 4.0,
            holdIn: 4.0,
            exhale: 4.0,
            holdOut: 4.0
        ),
        BreathingTechnique(
            id: "478",
            name: "4-7-8 Relax",
            description: "A natural tranquilizer for the nervous system. Best for falling asleep and reducing anxiety.",
            inhale: 4.0,
            holdIn: 7.0,
            exhale: 8.0,
            holdOut: 0.0
        ),
        BreathingTechnique(
            id: "equal",
            name: "Equal Breathing",
            description: "Balanced inhale and exhale to center the mind and improve focus.",
            inhale: 5.0,
            holdIn: 0.0,
            exhale: 5.0,
            holdOut: 0.0
        ),
        BreathingTechnique(
            id: "711",
            name: "7-11 Anxiety",
            description: "Forcing the exhale to be longer than the inhale triggers the body's 'rest and digest' response.",
            inhale: 7.0,
            holdIn: 0.0,
            exhale: 11.0,
            holdOut: 0.0
        ),
        BreathingTechnique(
            id: "resonant",
            name: "Resonant",
            description: "Optimal for heart rate variability. Relieves stress and balances the autonomic nervous system.",
            inhale: 6.0,
            holdIn: 0.0,
            exhale: 6.0,
            holdOut: 0.0
        ),
        BreathingTechnique(
            id: "fire",
            name: "Breath of Fire",
            description: "Energizing and detoxifying. Short, powerful exhales to wake up the body.",
            inhale: 1.0,
            holdIn: 0.0,
            exhale: 1.0,
            holdOut: 0.0
        ),
        BreathingTechnique(
            id: "relaxing",
            name: "Relaxing Breath",
            description: "Simple, deep breathing to slow down your heart rate and settle the mind.",
            inhale: 4.0,
            holdIn: 2.0,
            exhale: 6.0,
            holdOut: 0.0
        ),
        BreathingTechnique(
            id: "morning",
            name: "Morning Wakeup",
            description: "Quick inhale to energize with a short hold to circulate oxygen.",
            inhale: 2.0,
            holdIn: 1.0,
            exhale: 2.0,
            holdOut: 0.0
        ),
        BreathingTechnique(
            id: "power",
            name: "Power Breath",
            description: "Sharp inhales for physical performance and mental clarity.",
            inhale: 3.0,
            holdIn: 0.0,
            exhale: 2.0,
            holdOut: 0.0
        ),
        BreathingTechnique(
            id: "peace",
            name: "Deep Peace",
            description: "Ultra-long cycles for deep meditation and profound stillness.",
            inhale: 8.0,
            holdIn: 4.0,
            exhale: 10.0,
            holdOut: 2.0
        )
    ]
}
