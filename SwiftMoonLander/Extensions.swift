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

extension SIMD2<Float> {
    func normalised() -> SIMD2<Float> {
        let length = pow(pow(self.x, 2) + pow(self.y, 2), 0.5)
        return self / length;
    }
}
