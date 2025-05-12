// Generated using the ObjectBox Swift Generator — https://objectbox.io
// DO NOT EDIT
extension BarBaz: Equatable {}

// BarBaz has Annotations

func == (lhs: BarBaz, rhs: BarBaz) -> Bool {
    if lhs.parent != rhs.parent { return false }
    if lhs.otherVariable != rhs.otherVariable { return false }

    return true
}
