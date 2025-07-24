//
//  MyPlayground.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/23/25.
//


import SwiftUI


struct MyPlayground: View {
    
    let array1 = ["B","C","C","C","C","C","C","C","C","C","C","C","C","C","C","C","C","C","C","C","C","C","C","C"]
    var body: some View {
            TabView {
                NavigationStack{
                    List(array1, id: \.self) { item in
                        Text(item)
                    }
                    .navigationBarTitle("TabView Test")
                    .navigationBarTitleDisplayMode(.large)
                    .navigationDestination(for: String.self) { item in
                        Text("You tapped \(item)")
                    }

                }
                .tabItem { Text("Hi") }

                NavigationStack{
                    List(array1, id: \.self) { item in
                        Text(item)
                    }
                    .navigationBarTitle("TabView Test 2")
                    .navigationBarTitleDisplayMode(.large)

                }
                .tabItem { Text("2") }


        }
        
    }
    
}

#Preview {
    MyPlayground()
}
