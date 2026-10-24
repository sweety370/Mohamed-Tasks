
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MohamedTasksApp());
}

const ink = Color(0xFF252525);
const page = Color(0xFFF5F5F5);
const muted = Color(0xFF777777);

class MohamedTasksApp extends StatelessWidget {
  const MohamedTasksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mohamed Tasks',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: page,
        colorScheme: ColorScheme.fromSeed(seedColor: ink),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: ink,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: page,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const TasksHome(),
    );
  }
}

class TaskItem {
  String id;
  String title;
  String description;
  String priority;
  bool completed;
  DateTime createdAt;

  TaskItem({
    required this.id,
    required this.title,
    this.description = '',
    this.priority = 'عادية',
    this.completed = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'priority': priority,
        'completed': completed,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      priority: json['priority']?.toString() ?? 'عادية',
      completed: json['completed'] == true,
      createdAt: DateTime.tryParse(
            json['createdAt']?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }
}

class TasksHome extends StatefulWidget {
  const TasksHome({super.key});

  @override
  State<TasksHome> createState() => _TasksHomeState();
}

class _TasksHomeState extends State<TasksHome> {
  final List<TaskItem> tasks = [];
  final searchController = TextEditingController();

  String selectedFilter = 'الكل';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('mohamed_tasks_data');

    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List;
        tasks.addAll(
          decoded.map(
            (item) => TaskItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          ),
        );
      } catch (_) {
        // Ignore invalid saved data instead of crashing.
      }
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'mohamed_tasks_data',
      jsonEncode(tasks.map((task) => task.toJson()).toList()),
    );
  }

  int get completedCount => tasks.where((t) => t.completed).length;

  List<TaskItem> get filteredTasks {
    final query = searchController.text.trim().toLowerCase();

    return tasks.where((task) {
      final matchesFilter = switch (selectedFilter) {
        'قيد التنفيذ' => !task.completed,
        'مكتملة' => task.completed,
        _ => true,
      };

      final matchesSearch = task.title.toLowerCase().contains(query) ||
          task.description.toLowerCase().contains(query);

      return matchesFilter && matchesSearch;
    }).toList()
      ..sort((a, b) {
        if (a.completed != b.completed) {
          return a.completed ? 1 : -1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
  }

  Future<void> toggleTask(TaskItem task) async {
    setState(() => task.completed = !task.completed);
    await saveTasks();
  }

  Future<void> deleteTask(TaskItem task) async {
    setState(() => tasks.removeWhere((t) => t.id == task.id));
    await saveTasks();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حذف المهمة')),
    );
  }

  Future<void> editTask([TaskItem? task]) async {
    final titleController = TextEditingController(
      text: task?.title ?? '',
    );
    final descriptionController = TextEditingController(
      text: task?.description ?? '',
    );

    String priority = task?.priority ?? 'عادية';

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(task == null ? 'مهمة جديدة' : 'تعديل المهمة'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 380,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        autofocus: true,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: 'عنوان المهمة *',
                          hintText: 'مثال: إنهاء المشروع',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          labelText: 'الوصف',
                          hintText: 'تفاصيل إضافية (اختياري)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: priority,
                        decoration: const InputDecoration(
                          labelText: 'الأولوية',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'منخفضة',
                            child: Text('منخفضة'),
                          ),
                          DropdownMenuItem(
                            value: 'عادية',
                            child: Text('عادية'),
                          ),
                          DropdownMenuItem(
                            value: 'عالية',
                            child: Text('عالية'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => priority = value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: ink,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('اكتب عنوان المهمة أولاً'),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && mounted) {
      setState(() {
        if (task == null) {
          tasks.add(
            TaskItem(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              title: titleController.text.trim(),
              description: descriptionController.text.trim(),
              priority: priority,
            ),
          );
        } else {
          task.title = titleController.text.trim();
          task.description = descriptionController.text.trim();
          task.priority = priority;
        }
      });

      await saveTasks();
    }

    titleController.dispose();
    descriptionController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 850;

        return Scaffold(
          appBar: AppBar(
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, size: 27),
                SizedBox(width: 10),
                Text(
                  'Mohamed Tasks',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              if (desktop)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Center(
                    child: Text(
                      'BY MOHAMED APPS',
                      style: TextStyle(
                        color: muted,
                        fontSize: 11,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => editTask(),
            backgroundColor: ink,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('مهمة جديدة'),
          ),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (desktop) _buildSidebar(),
                    Expanded(
                      child: Directionality(
                        textDirection: TextDirection.rtl,
                        child: ListView(
                          padding: EdgeInsets.all(desktop ? 32 : 18),
                          children: [
                            Text(
                              'لوحة المهام',
                              style: TextStyle(
                                fontSize: desktop ? 30 : 25,
                                fontWeight: FontWeight.bold,
                                color: ink,
                              ),
                            ),
                            const SizedBox(height: 7),
                            const Text(
                              'نظّم يومك، مهمة واحدة في كل مرة.',
                              style: TextStyle(color: muted),
                            ),
                            const SizedBox(height: 24),
                            _buildStats(desktop),
                            const SizedBox(height: 26),
                            _buildSearch(),
                            const SizedBox(height: 16),
                            if (!desktop) _buildFilters(),
                            if (!desktop) const SizedBox(height: 12),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'المهام',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${filteredTasks.length} مهمة',
                                  style: const TextStyle(color: muted),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (filteredTasks.isEmpty)
                              _buildEmptyState()
                            else
                              ...filteredTasks.map(_buildTaskCard),
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildSidebar() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: 235,
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'مساحة العمل',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 28),
            for (final item in [
              ('الكل', Icons.dashboard_outlined),
              ('قيد التنفيذ', Icons.pending_actions),
              ('مكتملة', Icons.task_alt),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  selected: selectedFilter == item.$1,
                  selectedTileColor: const Color(0xFFEEEEEE),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Icon(item.$2),
                  title: Text(item.$1),
                  onTap: () => setState(() => selectedFilter = item.$1),
                ),
              ),
            const Spacer(),
            const Divider(),
            const Text(
              'MOHAMED APPS',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: muted,
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(bool desktop) {
    final total = tasks.length;
    final remaining = total - completedCount;

    final cards = [
      ('كل المهام', total.toString(), Icons.list_alt_outlined),
      ('قيد التنفيذ', remaining.toString(), Icons.pending_actions),
      ('مكتملة', completedCount.toString(), Icons.task_alt),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: desktop ? 3 : 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: desktop ? 112 : 102,
      ),
      itemBuilder: (context, index) {
        final item = cards[index];

        return Container(
          padding: EdgeInsets.all(desktop ? 18 : 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEAEAEA)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(item.$3, color: muted, size: 21),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      item.$1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: muted,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    item.$2,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: searchController,
      textDirection: TextDirection.rtl,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(
        hintText: 'ابحث عن مهمة...',
        prefixIcon: Icon(Icons.search),
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ['الكل', 'قيد التنفيذ', 'مكتملة'].map((filter) {
          final selected = selectedFilter == filter;

          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: ChoiceChip(
              label: Text(filter),
              selected: selected,
              onSelected: (_) {
                setState(() => selectedFilter = filter);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTaskCard(TaskItem task) {
    final priorityColor = switch (task.priority) {
      'عالية' => const Color(0xFFB3261E),
      'منخفضة' => const Color(0xFF47765A),
      _ => muted,
    };

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: Color(0xFFEAEAEA)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: ListTile(
          leading: Checkbox(
            value: task.completed,
            activeColor: ink,
            onChanged: (_) => toggleTask(task),
          ),
          title: Text(
            task.title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              decoration:
                  task.completed ? TextDecoration.lineThrough : null,
              color: task.completed ? muted : ink,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (task.description.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  task.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 7),
              Row(
                children: [
                  Icon(
                    Icons.flag_outlined,
                    size: 15,
                    color: priorityColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    task.priority,
                    style: TextStyle(
                      fontSize: 12,
                      color: priorityColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${task.createdAt.day}/${task.createdAt.month}/${task.createdAt.year}',
                    style: const TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            tooltip: 'خيارات المهمة',
            onSelected: (value) {
              if (value == 'edit') editTask(task);
              if (value == 'delete') deleteTask(task);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('تعديل'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('حذف'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.checklist_rounded,
            size: 50,
            color: Color(0xFFAAAAAA),
          ),
          const SizedBox(height: 12),
          Text(
            tasks.isEmpty ? 'ابدأ بأول مهمة!' : 'لا توجد نتائج',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tasks.isEmpty
                ? 'أضف مهمة جديدة لتنظيم يومك.'
                : 'جرّب تغيير البحث أو الفلتر.',
            style: const TextStyle(color: muted),
            textAlign: TextAlign.center,
          ),
          if (tasks.isEmpty) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => editTask(),
              icon: const Icon(Icons.add),
              label: const Text('إضافة مهمة'),
            ),
          ],
        ],
      ),
    );
  }
}
