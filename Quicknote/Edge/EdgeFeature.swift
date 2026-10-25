/// Edge tabs, app and site notes, reminders coming back (S07, S08). Owned by the Edge unit.
enum EdgeFeature {
    static func start() { EdgeController.shared.start() }
    static func hideForOneHour() { EdgeController.shared.hide(for: .seconds(60 * 60)) }
    /// The edge follows database changes by itself; this forces a redraw.
    static func refresh() { EdgeController.shared.reload() }
}
