//
//  ToDoWidgetBundle.swift
//  ToDoWidget
//
//  Created by asai on 2025/12/15.
//

import WidgetKit
import SwiftUI

@main
struct ToDoWidgetBundle: WidgetBundle {
    var body: some Widget {
        ToDoWidget()
        ToDoWidgetLiveActivity()
        ToDoWidgetControl()
    }
}
