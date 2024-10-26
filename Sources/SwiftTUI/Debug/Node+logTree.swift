import Foundation

extension Node {
    /// Log the tree underneath the current node.
    /// ```
    /// → ContentView
    ///   → VStack<Text>
    ///     → Text
    /// ```
    func logTree() {
        log(treeDescription)
    }

    var treeDescription: String {
        treeDescription(level: 0)
    }

    private func treeDescription(level: Int) -> String {
        var str = ""
        let indent = Array(repeating: " ", count: level * 2).joined()
        str += "\(indent)→ \(type(of: self.view!))"
        for child in children {
            str += "\n" + child.treeDescription(level: level + 1)
        }
        return str
    }
}
