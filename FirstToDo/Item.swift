//
//  Item.swift
//  FirstToDo
//
//  Created by asai on 2025/11/26.
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
