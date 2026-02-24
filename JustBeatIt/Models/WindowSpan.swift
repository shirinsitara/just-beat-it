import Foundation

struct WindowSpan: Identifiable, Hashable {
    let id = UUID()
    let startIndex: Int   // local index in visibleSamples
    let endIndex: Int   // local end 
    let beatNumber: Int
}
