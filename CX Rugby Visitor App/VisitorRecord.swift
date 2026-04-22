import Foundation

typealias VisitorRecord = VisitorSchemaV2.VisitorRecord

extension VisitorRecord {
    var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isActive: Bool {
        checkedOutAt == nil
    }
}
