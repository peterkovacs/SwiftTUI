import SwiftTUI
import Observation

@Observable class Model {
    var toDos: [ToDo] = [
        ToDo(text: "Hello"),
        ToDo(text: "World")
    ]

    func onDelete(_ toDo: ToDo) {
        toDos.removeAll(where: { $0.id == toDo.id })
    }

    func add(text: String) {
        toDos.append(ToDo(text: text))
    }
}

struct ToDoList: View {
    @State var model: Model = Model()

    var body: some View {
        VStack(spacing: 1) {
            VStack {
                ForEach(model.toDos) { toDo in
                    ToDoView(toDo: toDo, onDelete: { model.onDelete(toDo) })
                }
            }
            addToDo
            Spacer()
        }
    }

    private var addToDo: some View {
        HStack {
            Text("New to-do: ")
                .italic()
            TextField() { model.add(text: $0) }
            Spacer()
        }
    }
}
