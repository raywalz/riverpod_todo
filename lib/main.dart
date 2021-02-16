import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'todo.dart';

/// Some keys used for testing
final addTodoKey = UniqueKey();
final activeFilterKey = UniqueKey();
final completedFilterKey = UniqueKey();
final allFilterKey = UniqueKey();

final todoListProvider = StateNotifierProvider((ref) {
  return TodoList();
});

/// The different ways to filter the list of todos
enum TodoListFilter {
  all,
  active,
  completed,
}

/// The currently active filter.
///
/// We use [StateProvider] here as there is no fancy logic behind manipulating
/// the value since it's just enum.
final todoListFilter = StateProvider((_) => TodoListFilter.all);

/// The number of uncompleted todos
///
/// By using [Provider], this value is cached, making it performant.\
/// Even multiple widgets try to read the number of uncompleted todos,
/// the value will be computed only once (until the todo-list changes).
///
/// This will also optimise unneeded rebuilds if the todo-list changes, but the
/// number of uncompleted todos doesn't (such as when editing a todo).
final uncompletedTodosCount = Provider((ref) {
  return ref
      .watch(todoListProvider.state)
      .where((todo) => !todo.completed)
      .length;
});

/// The list of todos after applying of [todoListFilter].
///
/// This too uses [Provider], to avoid recomputing the filtered list unless either
/// the filter of or the todo-list updates.
final filteredTodos = Provider((ref) {
  final filter = ref.watch(todoListFilter);
  final todos = ref.watch(todoListProvider.state);

  switch (filter.state) {
    case TodoListFilter.completed:
      return todos.where((todo) => todo.completed).toList();
    case TodoListFilter.active:
      return todos.where((todo) => !todo.completed).toList();
    case TodoListFilter.all:
    default:
      return todos;
  }
});

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Home(),
    );
  }
}

class Home extends HookWidget {
  const Home({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final todos = useProvider(filteredTodos);
    final newTodoController = useTextEditingController();

    void _submitTextField(value) {
      if (value != '') {
        context.read(todoListProvider).add(value);
        newTodoController.clear();
      }
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      if (todos.isNotEmpty) const Divider(height: 0),
                      if (todos.isEmpty)
                        const Text(
                          'Use the text field below to add some tasks',
                          style: TextStyle(
                            fontSize: 24,
                          ),
                        ),
                      for (var i = 0; i < todos.length; i++) ...[
                        if (i > 0) const Divider(height: 0),
                        Dismissible(
                          key: ValueKey(todos[i].id),
                          onDismissed: (_) {
                            context.read(todoListProvider).remove(todos[i]);
                          },
                          child: ProviderScope(
                            overrides: [
                              _currentTodo.overrideWithValue(todos[i]),
                            ],
                            child: const TodoItem(),
                          ),
                        )
                      ],
                    ],
                  ),
                ),
                TextField(
                  key: addTodoKey,
                  controller: newTodoController,
                  decoration: InputDecoration(
                    labelText: 'Add new task here',
                    suffixIcon: IconButton(
                      icon: Icon(Icons.add),
                      onPressed: () =>
                          _submitTextField(newTodoController.value.text),
                    ),
                  ),
                  onSubmitted: (value) => _submitTextField(value),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A provider which exposes the [Todo] displayed by a [TodoItem].
///
/// By retreiving the [Todo] through a provider instead of through its
/// constructor, this allows [TodoItem] to be instantiated using the `const` keyword.
///
/// This ensures that when we add/remove/edit todos, only what the
/// impacted widgets rebuilds, instead of the entire list of items.
final _currentTodo = ScopedProvider<Todo>(null);

class TodoItem extends HookWidget {
  const TodoItem({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final todo = useProvider(_currentTodo);
    final itemFocusNode = useFocusNode();
    // listen to focus chances
    useListenable(itemFocusNode);
    final isFocused = itemFocusNode.hasFocus;

    final textEditingController = useTextEditingController();
    final textFieldFocusNode = useFocusNode();

    return Material(
      elevation: 6,
      child: Focus(
        focusNode: itemFocusNode,
        onFocusChange: (focused) {
          if (focused) {
            textEditingController.text = todo.description;
          } else {
            // Commit changes only when the textfield is unfocused, for performance
            context
                .read(todoListProvider)
                .edit(id: todo.id, description: textEditingController.text);
          }
        },
        child: ListTile(
          onTap: () {
            itemFocusNode.requestFocus();
            textFieldFocusNode.requestFocus();
          },
          leading: Checkbox(
            value: todo.completed,
            onChanged: (value) =>
                context.read(todoListProvider).toggle(todo.id),
          ),
          title: isFocused
              ? TextField(
                  autofocus: true,
                  focusNode: textFieldFocusNode,
                  controller: textEditingController,
                )
              : Text(todo.description),
        ),
      ),
    );
  }
}
