import SwiftUI

struct JellyfinLoginView: View {
    @Binding var isPresented: Bool
    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ZStack {
                PrismBackground()
                
                VStack(spacing: 20) {
                    Text("Connect to Jellyfin")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    VStack(spacing: 15) {
                        ServerURLTextField(text: $serverURL)
                        CustomTextField(placeholder: "Username", text: $username)
                        CustomSecureField(placeholder: "Password", text: $password)
                        
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal)
                    
                    Button(action: {
                        isLoading = true
                        errorMessage = ""
                        let fullURL = "http://\(serverURL)"
                        JellyfinService.shared.authenticate(server: fullURL, username: username, password: password) { result in
                            Task { @MainActor in
                                isLoading = false
                                switch result {
                                case .success:
                                    isPresented = false
                                case .failure(let error):
                                    errorMessage = "Login failed: \(error.localizedDescription)"
                                }
                            }
                        }
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .padding(.trailing, 5)
                            }
                            Text("Connect")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .cornerRadius(10)
                    }
                    .disabled(isLoading)
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
}

struct CustomTextField: View {
    var placeholder: String
    @Binding var text: String
    
    var body: some View {
        TextField(placeholder, text: $text)
            .textInputAutocapitalization(.never)
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
            .foregroundColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
    }
}

struct CustomSecureField: View {
    var placeholder: String
    @Binding var text: String
    
    var body: some View {
        SecureField(placeholder, text: $text)
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
            .foregroundColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
    }
}

struct ServerURLTextField: View {
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 0) {
            Text("http://")
                .foregroundColor(.white.opacity(0.6))
                .padding(.leading, 15)
            
            TextField("192.168.1.5:8096", text: $text)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .foregroundColor(.white)
        }
        .padding(.vertical, 15)
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    JellyfinLoginView(isPresented: .constant(true))
}
