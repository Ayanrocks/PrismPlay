import SwiftUI

struct ServerManagementView: View {
    @ObservedObject private var jellyfinService = JellyfinService.shared
    @State private var showAddServer = false
    @State private var showEditServer = false
    @State private var editingServer: JellyfinServerConfig?
    @State private var editingServerIndex: Int = 0
    
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
                        ForEach(Array(jellyfinService.savedServers.enumerated()), id: \.element.id) { index, server in
                            NavigationLink(destination: ServerLibrariesView(server: server)) {
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
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteServer(at: IndexSet(integer: index))
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                Button {
                                    print("Edit button tapped for server at index: \(index)")
                                    print("Server name: \(server.name)")
                                    print("Server url: \(server.url)")
                                    print("Server username: \(server.username)")
                                    editingServerIndex = index
                                    editingServer = server
                                    showEditServer = true
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.purple)
                            }
                        }
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
        .sheet(isPresented: $showEditServer) {
            if let editingServer = editingServer {
                ServerEditView(
                    isPresented: $showEditServer,
                    server: editingServer,
                    serverIndex: editingServerIndex
                )
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
