//
//  ContentView.swift
//  watch Extension
//
//  Created by Amorn Apichattanakul on 17/4/21.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: WatchViewModel = WatchViewModel()
    
    var body: some View {
        VStack {
            Text("HBPM: \(viewModel.counter)").font(.system(size: 22, weight: .light, design: .default))
                .padding()
            Button(action: {
                viewModel.endWorkout()
                exit(EXIT_SUCCESS)
            }) {
                Text("Exit")
            }
//            Button(action: {
//                viewModel.sendDataMessage(for: .sendCounterToFlutter, data: ["counter": viewModel.heartReate])
//            }) {
//                Text("Update heartbeat")
//            }
        }
        
        
    }
}
