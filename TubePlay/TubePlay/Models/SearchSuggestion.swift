import Foundation

public struct SearchSuggestion: Identifiable, Hashable, Equatable {
    public let id: String
    public let text: String
    
    public init(text: String) {
        self.id = text
        self.text = text
    }
}
