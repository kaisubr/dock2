
import Foundation

public enum WindowAction: Equatable {
    case toggle
    case open
    case minimize
    case quit
    case reorder(Int?)
}
