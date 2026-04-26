import Foundation
import SwiftData

enum VisitorSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [VisitorRecord.self]
    }

    @Model
    final class VisitorRecord {
        var id: UUID
        var firstName: String
        var lastName: String
        var identityType: String
        var identityNumber: String
        var company: String
        var host: String
        var carRegistration: String
        var checkInAt: Date
        var checkedOutAt: Date?
        var checkoutMethod: String
        var createdAt: Date

        init(
            id: UUID = UUID(),
            firstName: String,
            lastName: String,
            identityType: String,
            identityNumber: String,
            company: String,
            host: String,
            carRegistration: String = "",
            checkInAt: Date = Date(),
            checkedOutAt: Date? = nil,
            checkoutMethod: String = "",
            createdAt: Date = Date()
        ) {
            self.id = id
            self.firstName = firstName
            self.lastName = lastName
            self.identityType = identityType
            self.identityNumber = identityNumber
            self.company = company
            self.host = host
            self.carRegistration = carRegistration
            self.checkInAt = checkInAt
            self.checkedOutAt = checkedOutAt
            self.checkoutMethod = checkoutMethod
            self.createdAt = createdAt
        }
    }
}

enum VisitorSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [VisitorRecord.self]
    }

    @Model
    final class VisitorRecord {
        var id: UUID
        var firstName: String
        var lastName: String
        var company: String
        var host: String
        var carRegistration: String
        var checkInAt: Date
        var checkedOutAt: Date?
        var checkoutMethod: String
        var createdAt: Date

        init(
            id: UUID = UUID(),
            firstName: String,
            lastName: String,
            company: String,
            host: String,
            carRegistration: String = "",
            checkInAt: Date = Date(),
            checkedOutAt: Date? = nil,
            checkoutMethod: String = "",
            createdAt: Date = Date()
        ) {
            self.id = id
            self.firstName = firstName
            self.lastName = lastName
            self.company = company
            self.host = host
            self.carRegistration = carRegistration
            self.checkInAt = checkInAt
            self.checkedOutAt = checkedOutAt
            self.checkoutMethod = checkoutMethod
            self.createdAt = createdAt
        }
    }
}

enum VisitorMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [VisitorSchemaV1.self, VisitorSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: VisitorSchemaV1.self, toVersion: VisitorSchemaV2.self)
        ]
    }
}

