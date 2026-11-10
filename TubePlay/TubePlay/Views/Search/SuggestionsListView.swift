import SwiftUI

public struct SuggestionsListView: View {
    let suggestions: [SearchSuggestion]
    let onSelect: (String) -> Void
    let onAutoComplete: (String) -> Void
    
    public init(
        suggestions: [SearchSuggestion],
        onSelect: @escaping (String) -> Void,
        onAutoComplete: @escaping (String) -> Void
    ) {
        self.suggestions = suggestions
        self.onSelect = onSelect
        self.onAutoComplete = onAutoComplete
    }
    
    public var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(suggestions) { item in
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                        .frame(width: 20)
                    
                    Text(item.text)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(item.text)
                        }
                    
                    Button(action: {
                        onAutoComplete(item.text)
                    }) {
                        Image(systemName: "arrow.up.left")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                            .frame(width: 32, height: 32)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                
                Divider()
                    .padding(.leading, 48)
            }
        }
        .background(Color(UIColor.systemBackground))
    }
}
