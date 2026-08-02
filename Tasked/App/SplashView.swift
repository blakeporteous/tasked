//
//  SplashView.swift
//  Tasked
//
//  Created by Blake Porteous on 02/08/2026.
//

import SwiftUI

struct SplashView: View {

    @State private var isBreathing = false

    var body: some View {

        ZStack {

            Color.white
                .ignoresSafeArea()

            Image(systemName: "scroll.fill")
                .font(.system(size: 90))
                .foregroundStyle(.blue)
                .scaleEffect(isBreathing ? 1.12 : 0.9)
                .opacity(isBreathing ? 1.0 : 0.7)

        }
        .onAppear {

            withAnimation(
                .easeInOut(duration: 1.6)
                    .repeatForever(autoreverses: true)
            ) {
                isBreathing = true
            }

        }
    }
}
