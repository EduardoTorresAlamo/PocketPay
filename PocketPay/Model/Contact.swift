//
//  Contact.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import Foundation

struct Contact: Identifiable, Codable {
    let id: UUID
    let name: String
    let phoneNumber: String
    let avatarUrl: String?
    var isFavorite: Bool

    init(id: UUID = UUID(), name: String, phoneNumber: String, avatarUrl: String? = nil, isFavorite: Bool = false) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.avatarUrl = avatarUrl
        self.isFavorite = isFavorite
    }

    var initials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            let first = components[0].prefix(1)
            let last = components[1].prefix(1)
            return "\(first)\(last)".uppercased()
        } else if let first = components.first {
            return String(first.prefix(1)).uppercased()
        }
        return "?"
    }

    // Mock contacts
    static var mockContacts: [Contact] {
        [
            Contact(name: "Jose Rivera", phoneNumber: "+1 787 555 0001", isFavorite: true),
            Contact(name: "Maria Garcia", phoneNumber: "+1 787 555 0002", isFavorite: true),
            Contact(name: "Carlos Santos", phoneNumber: "+1 787 555 0003"),
            Contact(name: "Ana Martinez", phoneNumber: "+1 787 555 0004"),
            Contact(name: "Luis Rodriguez", phoneNumber: "+1 787 555 0005"),
            Contact(name: "Sofia Hernandez", phoneNumber: "+1 787 555 0006"),
            Contact(name: "Miguel Torres", phoneNumber: "+1 787 555 0007"),
            Contact(name: "Isabella Lopez", phoneNumber: "+1 787 555 0008"),
            Contact(name: "Diego Perez", phoneNumber: "+1 787 555 0009"),
            Contact(name: "Valentina Cruz", phoneNumber: "+1 787 555 0010")
        ]
    }
}
