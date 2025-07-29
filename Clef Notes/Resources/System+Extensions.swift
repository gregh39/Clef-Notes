import SwiftUI

// This extension allows the Color type to be saved in AppStorage.
extension Color: RawRepresentable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let components = try? JSONDecoder().decode([CGFloat].self, from: data) else {
            return nil
        }
        self = Color(.sRGB, red: components[0], green: components[1], blue: components[2], opacity: components[3])
    }

    public var rawValue: String {
        guard let cgColor = self.cgColor,
              let components = cgColor.components,
              components.count >= 3 else {
            return ""
        }
        let colorArray = [components[0], components[1], components[2], cgColor.alpha]
        guard let data = try? JSONEncoder().encode(colorArray) else {
            return ""
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
