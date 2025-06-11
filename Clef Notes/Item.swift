//
//  Item.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/10/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
