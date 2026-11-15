import SwiftUI

extension Binding where Value == Bool {
    /// `true` while `source` holds a value; setting `false` clears it. Drives alerts and dialogs.
    public init<Wrapped>(isPresent source: Binding<Wrapped?>) {
        self = source[dynamicMember: \.isPresent]
    }
}

extension Binding where Value == Int {
    /// The value as a `Double`, rounded back to the nearest integer when set. Drives sliders.
    public var asDouble: Binding<Double> {
        self[dynamicMember: \.roundedDouble]
    }
}

extension ClosedRange where Bound == Int {
    /// The same range as `Double`s, for sliders.
    public var asDouble: ClosedRange<Double> {
        Double(lowerBound)...Double(upperBound)
    }
}

extension Optional {
    fileprivate var isPresent: Bool {
        get { self != nil }
        set { if !newValue { self = nil } }
    }
}

extension Int {
    fileprivate var roundedDouble: Double {
        get { Double(self) }
        set { self = Int(newValue.rounded()) }
    }
}
