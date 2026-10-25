/// Edge tabs, app and site notes, reminders coming back (S07, S08). Owned by the Edge unit.
enum EdgeFeature {
    static func start() {}
    static func hideForOneHour() {}
    /// Call after any change to notes so the edge redraws.
    static func refresh() {}
}
