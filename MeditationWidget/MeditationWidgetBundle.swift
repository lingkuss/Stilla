//
//  MeditationWidgetBundle.swift
//  MeditationWidget
//
//  Created by Elias Nilsson on 2026-03-31.
//

import WidgetKit
import SwiftUI

@main
struct MeditationWidgetBundle: WidgetBundle {
    var body: some Widget {
        MeditationWidget()
        MeditationWidgetControl()
        MeditationWidgetLiveActivity()
    }
}
