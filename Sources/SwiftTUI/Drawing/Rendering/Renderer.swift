@MainActor
protocol Renderer: AnyObject {
    var window: Window { get }
    var layer: Layer { get }
    var application: Application? { get set }

    func setSize()

    /// Schedule an update to update any layers that have been invalidated.
    func scheduleUpdate()
    /// Draw only the invalidated part of the layer.
    func update()
    /// Draw a specific area, or the entire layer if the area is nil.
    func draw(rect: Rect?)
    /// Terminate the Renderer
    func stop()
}
