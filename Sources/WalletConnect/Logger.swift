// 

import Foundation
import Iridium

public protocol ConsoleLogging: Iridium.ConsoleLogging {
    func debug(_ items: Any...)
    func info(_ items: Any...)
    func warn(_ items: Any...)
    func error(_ items: Any...)
}
