import SwiftUI

public struct SearchBarView: View {
    @Binding var text: String
    var isSearching: Bool
    var onCommit: () -> Void
    var onClear: () -> Void
    
    @FocusState private var isFocused: Bool
    
    public init(
        text: Binding<String>,
        isSearching: Bool,
        onCommit: @escaping () -> Void,
        onClear: @escaping () -> Void
    ) {
        self._text = text
        self.isSearching = isSearching
        self.onCommit = onCommit
        self.onClear = onClear
    }
    
    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 17, weight: .medium))
            
            TextField("Search YouTube or paste URL...", text: $text)
                .focused($isFocused)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .submitLabel(.search)
                .onSubmit {
                    onCommit()
                }
            
            if isSearching {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.trailing, 2)
            } else if !text.isEmpty {
                Button(action: {
                    text = ""
                    onClear()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}
