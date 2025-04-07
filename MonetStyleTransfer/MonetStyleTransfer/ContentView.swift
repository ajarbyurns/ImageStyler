//
//  ContentView.swift
//  MonetStyleTransfer
//
//  Created by Barry Juans on 07/04/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack {
                NavigationLink(destination: CameraView()) {
                    Text("Start")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .background(Color.white)
        }
    }
}
