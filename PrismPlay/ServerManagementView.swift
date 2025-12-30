import SwiftUI

struct ServerManagementView: View {
    @ObservedObject private var jellyfinService = JellyfinService.shared
    @State private var showAddServer = false
    
    var body: some View {
        ZStack {
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
                            Button(action: {
                                jellyfinService.selectServer(server)
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(server.name)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Text(server.url)
                                            .font(.subheadline)
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    Spacer()
                                    if jellyfinService.isAuthenticated && jellyfinService.serverURL == server.url && jellyfinService.userId == server.userId {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.green)
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .font(.footnote)
                                            .foregroundColor(.white.opacity(0.3))
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color.white.opacity(0.1))
                                        .background(
                                            RoundedRectangle(cornerRadius: 15)
                                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                )
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                        .onDelete(perform: deleteServer)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Servers")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showAddServer = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddServer) {
            JellyfinLoginView(isPresented: $showAddServer)
        }
    }
    
    func deleteServer(at offsets: IndexSet) {
        jellyfinService.removeServer(at: offsets)
    }
}

#Preview {
    ServerManagementView()
}
