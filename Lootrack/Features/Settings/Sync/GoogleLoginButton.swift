import SwiftUI

struct GoogleLoginButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image("GoogleIcon")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                
                Text("Sign in with Google")
                    .fontWeight(.semibold)
                
                Spacer()
            }
            .padding(.horizontal, 18)
            .frame(height: 56)
            .foregroundStyle(.primary)
            .background(.thinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.12))
            }
        }
        .buttonStyle(.plain)
    }
}
