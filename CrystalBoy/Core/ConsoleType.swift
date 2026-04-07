import SwiftUI

enum ConsoleType: String, CaseIterable, Codable {
    case gb, gbc, gba, nes, snes, genesis

    var displayName: String {
        switch self {
        case .gb: return "Game Boy"
        case .gbc: return "GBC"
        case .gba: return "GBA"
        case .nes: return "NES"
        case .snes: return "SNES"
        case .genesis: return "Genesis"
        }
    }

    var extensions: [String] {
        switch self {
        case .gb: return ["gb"]
        case .gbc: return ["gbc"]
        case .gba: return ["gba"]
        case .nes: return ["nes"]
        case .snes: return ["sfc", "smc"]
        case .genesis: return ["md", "gen"]
        }
    }

    var badgeColor: Color {
        switch self {
        case .gb: return .gray
        case .gbc: return .purple
        case .gba: return .indigo
        case .nes: return .red
        case .snes: return .blue
        case .genesis: return .orange
        }
    }

    /// Console types with compiled cores available. Update as cores are added in Phases 1-4.
    static let availableCores: Set<ConsoleType> = [.gb, .gbc, .gba, .nes, .snes, .genesis]

    /// File extensions for available cores only
    static var availableExtensions: Set<String> {
        Set(availableCores.flatMap { $0.extensions })
    }

    /// All supported file extensions across all consoles
    static var allExtensions: Set<String> {
        Set(allCases.flatMap { $0.extensions })
    }

    /// Determine console type from a file extension
    static func from(extension ext: String) -> ConsoleType? {
        let lower = ext.lowercased()
        return allCases.first { $0.extensions.contains(lower) }
    }
}
