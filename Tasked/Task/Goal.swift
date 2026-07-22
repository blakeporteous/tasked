//
//  Task.swift
//  Tasked
//
//  Created by Blake Porteous on 20/10/2025.
//

import SwiftUI

struct Goal: View {
    var body: some View {
        ZStack {
            Color(.systemBackground) // Full screen background
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("Weekly Task")
                        .padding(.bottom, 20)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("- Play a round")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("   of golf")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .padding(40)
                .frame(maxWidth: .infinity) // Make box expand horizontally
                .background(Color.blue)
                .cornerRadius(25)
                .shadow(radius: 10)
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
    }
}

struct Goal_Previews: PreviewProvider {
    static var previews: some View {
        Goal()
    }
}

