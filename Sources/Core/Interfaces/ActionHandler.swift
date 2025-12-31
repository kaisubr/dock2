
import Foundation

public protocol ActionHandler {
    func perform(_ action: WindowAction, on window: WindowModel)
    func constrainWindow(pid: Int32, id: UInt32, limitY: Double)
}
