import Foundation

struct BeatWindow: Identifiable, Hashable {
    let id = UUID()

    let rIndex: Int
    let startIndex: Int
    let endIndex: Int      // end is exclusive
}

