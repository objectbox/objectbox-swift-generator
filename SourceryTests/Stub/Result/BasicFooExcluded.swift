// Generated using the ObjectBox Swift Generator — https://objectbox.io
// DO NOT EDIT

extension Bar: Equatable {}

// Bar has Annotations

func == (lhs: Bar, rhs: Bar) -> Bool {
    if lhs.parent != rhs.parent { return false }
    if lhs.otherVariable != rhs.otherVariable { return false }

    return true
}
