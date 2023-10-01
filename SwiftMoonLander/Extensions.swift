import Foundation

extension Bool {
    var toFloat: Float {
        self ? 1 : 0
    }
}

extension Float {
    var toCGFloat: CGFloat {
        CGFloat(self)
    }
}
