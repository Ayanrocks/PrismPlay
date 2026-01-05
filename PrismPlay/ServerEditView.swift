import SwiftUI

struct ServerEditView: View {
    @Binding var isPresented: Bool
    let server: JellyfinServerConfig
    let serverIndex: Int
    
    @State private var serverURL: String
    @State private var username: String
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    init(isPresented: Binding<Bool>, server: JellyfinServerConfig, serverIndex: Int) {
        self._isPresented = isPresented
        self.server = server
        self.serverIndex = serverIndex
        
        // Initialize state from server config
        let urlWithoutProtocol = server.url.replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "https://", with: "")
        _serverURL = State(initialValue: urlWithoutProtocol)
        _username = State(initialValue: server.username)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                PrismBackground()
                
                VStack(spacing: 20) {
                    Text("Edit Server")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    VStack(spacing: 15) {
                        ServerURLTextField(text: $serverURL)
                        CustomTextField(placeholder: "Username", text: $username)
                        CustomSecureField(placeholder: "Password (optional)", text: $password)
                        
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        
                        Text("Leave password blank to keep existing credentials")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    
                    HStack(spacing: 15) {
                        Button(action: {
                            isPresented = false
                        }) {
                            Text("Cancel")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(10)
                        }
                        
                        Button(action: saveChanges) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .padding(.trailing, 5)
                                }
                                Text("Save")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .cornerRadius(10)
                        }
                        .disabled(isLoading)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    Spacer()
                }
                .padding(.top, 50)
            }
            .navigationBarItems(trailing: Button("Cancel") {
                isPresented = false
            })
        }
    }
    
    func saveChanges() {
        errorMessage = ""
        
        // If password is provided, re-authenticate
        if !password.isEmpty {
            isLoading = true
            let fullURL = "http://\(serverURL)"
            
            JellyfinService.shared.authenticate(server: fullURL, username: username, password: password) { result in
                Task { @MainActor in
                    isLoading = false
                    switch result {
                    case .success:
                        // Update the server with new credentials
                        var updatedServer = server
                        updatedServer.url = fullURL
                        updatedServer.username = username
                        updatedServer.name = username
                        
                        // The authenticate method already updated the service, now update the saved server
                        JellyfinService.shared.updateServer(at: serverIndex, with: updatedServer)
                        isPresented = false
                        
                    case .failure(let error):
                        errorMessage = "Authentication failed: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            // Just update URL and username without re-authenticating
            var updatedServer = server
            updatedServer.url = "http://\(serverURL)"
            updatedServer.username = username
            updatedServer.name = username
            
            JellyfinService.shared.updateServer(at: serverIndex, with: updatedServer)
            isPresented = false
        }
    }
}
