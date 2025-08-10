import SwiftUI

struct ContentView2: View {
    @State private var selectedTab = 0
    private let titles = ["People", "Fruits", "Sports", "Cities"]

    var body: some View {
        TabView {
            NavigationStack {
                List(["Alice", "Bob", "Charlie", "Diana"], id: \.self, rowContent: Text.init)
                    .navigationTitle("People")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar(.visible, for: .navigationBar)
            }
            .tabItem { Label("People", systemImage: "person.3") }

            NavigationStack {
                List(["Apple", "Banana", "Cherry", "Date"], id: \.self, rowContent: Text.init)
                    .navigationTitle("Fruits")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar(.visible, for: .navigationBar)
            }
            .tabItem { Label("Fruits", systemImage: "leaf") }

            NavigationStack {
                List(["Soccer", "Basketball", "Tennis", "Baseball"], id: \.self, rowContent: Text.init)
                    .navigationTitle("Sports")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar(.visible, for: .navigationBar)
            }
            .tabItem { Label("Sports", systemImage: "sportscourt") }

            NavigationStack {
                List(["Paris", "London", "Tokyo", "New York"], id: \.self, rowContent: Text.init)
                    .navigationTitle("Cities")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar(.visible, for: .navigationBar)
            }
            .tabItem { Label("Cities", systemImage: "building.2") }
        }
    }
}

#Preview { ContentView2() }
