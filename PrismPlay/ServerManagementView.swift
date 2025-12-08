import SwiftUI

struct ServerManagementView: View {
    @ObservedObject private var jellyfinService = JellyfinService.shared
    @State private var showAddServer = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                // Background
                PrismBackground()
                
                VStack {
                    if jellyfinService.savedServers.isEmpty {
                        VStack(spacing: 20) {
                            Spacer()
                            Image(systemName: "server.rack")
                                .font(.system(size: 80))
                                .foregroundColor(.gray)
                            
                            Text("No Servers Added")
                                .font(.title)
                                .foregroundColor(.gray)
                            
                            Button(action: {
                                showAddServer = true
                            }) {
                                Text("Add Jellyfin Server")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.purple)
                                    .cornerRadius(10)
                            }
                            Spacer()
                        }
                    } else {
                        List {
                            ForEach(jellyfinService.savedServers) { server in
                                NavigationLink(destination: MediaLibraryView().onAppear {
                                    jellyfinService.selectServer(server)
                                }) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(server.name)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            Text(server.url)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        if jellyfinService.isAuthenticated && jellyfinService.serverURL == server.url && jellyfinService.userId == server.userId {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                        }
                                    }
                                    .padding(.vertical, 8)
                                }
                            }
                            .onDelete(perform: deleteServer)
                        }
                        .listStyle(InsetGroupedListStyle())
                    }
                }
            }
            .navigationTitle("Servers")
            .navigationBarItems(trailing: Button(action: {
                showAddServer = true
            }) {
                Image(systemName: "plus")
            })
            .sheet(isPresented: $showAddServer) {
                JellyfinLoginView(isPresented: $showAddServer)
            }
        }
    }
    
    func deleteServer(at offsets: IndexSet) {
        jellyfinService.removeServer(at: offsets)
    }
}

#Preview {
    ServerManagementView()
}
