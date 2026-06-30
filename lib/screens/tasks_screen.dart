import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/family_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _titleController = TextEditingController();
  final _rewardController = TextEditingController();

  String? _selectedChild;
  bool _allChildren = false;

  String _familyId = "";
  String _userName = "";

  List<dynamic> _children = [];
  List<dynamic> _tasks = [];

  String? _historyFilter;

  bool _loading = true;

  String _role = "child";

  List<Map<String, dynamic>> _childBalances = []; // новый формат

  List<Map<String, dynamic>> _pendingPayouts = [];

  String _repeatMode = "none";

  List<dynamic> _rewardTypes = [];
  int? _selectedRewardTypeId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final family = await FamilyStorage.loadFamily();
    _role = family["role"] ?? "child";

    _familyId = family["family_id"] ?? "";
    _userName = family["user_name"] ?? "";

    final members = await ApiService.getMembers(_familyId);
    final tasks = await ApiService.getTasks(_familyId, null);

    if (_role == "child") {
      final balanceData = await ApiService.getChildBalance(_familyId, _userName);
      final balancesRaw = balanceData["balances"] ?? [];
      final pendingRaw = balanceData["pending_payouts"] ?? [];
      _childBalances = (balancesRaw as List<dynamic>)
    .map((e) => Map<String, dynamic>.from(e as Map))
    .toList();
    _pendingPayouts = (pendingRaw as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
          }

    _rewardTypes = await ApiService.getRewardTypes(_familyId);

    if (_rewardTypes.isNotEmpty && _selectedRewardTypeId == null) {
      _selectedRewardTypeId = _rewardTypes.first["id"];
    }

    setState(() {
      _children = (members?["members"] ?? [])
          .where((m) => m["role"] == "child")
          .toList();
      _tasks = tasks;
      _loading = false;
    });
  }

  Future<void> _createTask() async {
    if (_selectedChild == null && !_allChildren) return;

    final title = _titleController.text.trim();
    final reward = int.tryParse(_rewardController.text) ?? 0;

    if (title.isEmpty || reward <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Заполните описание и награду")),
      );
      return;
    }

    if (_allChildren) {
      // Создаём по задаче каждому ребёнку
      for (final child in _children) {
        await ApiService.createTask(
          familyId: _familyId,
          title: title,
          rewardAmount: reward,
          rewardTypeId: _selectedRewardTypeId!,
          createdBy: _userName,
          assignedTo: child["user_name"],
          repeatMode: _repeatMode,
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Создано задач: ${_children.length}")),
      );
    } else {
      await ApiService.createTask(
        familyId: _familyId,
        title: title,
        rewardAmount: reward,
        rewardTypeId: _selectedRewardTypeId!,
        createdBy: _userName,
        assignedTo: _selectedChild!,
        repeatMode: _repeatMode,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Задача создана")),
      );
    }

    _titleController.clear();
    _rewardController.clear();
    await _loadData();
  }

  Future<void> _deleteTask(int taskId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Удалить задание?"),
        content: const Text("Это действие нельзя отменить."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Отмена"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Удалить"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ApiService.deleteTask(taskId, _userName);
    _loadData();
  }

  Future<void> _showPayoutDialog(

    String childName,
    List<Map<String,dynamic>> balances,

) async {

    final selected=<int>{};

    await showDialog(

      context: context,

      builder:(context){

        return StatefulBuilder(

          builder:(context,setState){

            return AlertDialog(

              title: Text(
                "Выплата — $childName",
              ),

              content: SizedBox(

                width:400,

                child:Column(

                  mainAxisSize:
                      MainAxisSize.min,

                  children:[

                    ...balances.map(

                      (b){

                        final id=b["reward_type_id"];

                        return CheckboxListTile(

                          value:selected.contains(id),

                          title:Text(

                            b["type"],

                            style:const TextStyle(

                              fontWeight:
                                  FontWeight.bold,

                            ),

                          ),

                          subtitle:Text(

                            "Доступно: ${b["amount"]}",

                          ),

                          onChanged:(v){

                            setState((){

                              if(v==true){

                                selected.add(id);

                              }else{

                                selected.remove(id);

                              }

                            });

                          },

                        );

                      },

                    ),

                  ],

                ),

              ),

              actions:[

                TextButton(

                  onPressed:(){

                    Navigator.pop(context);

                  },

                  child:const Text(
                    "Отмена",
                  ),

                ),

                ElevatedButton(

                  onPressed:()async{

                    await ApiService.createPayout(

                      _familyId,

                      childName,

                      rewardTypeIds:
                          selected.toList(),

                    );

                    Navigator.pop(context);

                    _loadData();

                  },

                  child:const Text(
                    "Выплатить выбранное",
                  ),

                ),

                ElevatedButton(

                  onPressed:()async{

                    await ApiService.createPayout(

                      _familyId,

                      childName,

                    );

                    Navigator.pop(context);

                    _loadData();

                  },

                  child:const Text(
                    "Выплатить всё",
                  ),

                ),

              ],

            );

          },

        );

      },

    );

}


Future<void> _confirmPayout(int payoutId) async {
  final ok = await ApiService.confirmPayout(payoutId, _userName);
  if (!ok) return;
  await _loadData();
  setState(() {});
}

Future<void> _cancelPayout(int payoutId) async {
  final ok = await ApiService.cancelPayout(payoutId);
  if (!ok) return;
  await _loadData();

  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("Выплата отменена. Сообщите родителю."),
    ),
  );

  setState(() {});
}



Widget _buildPendingPayoutCard() {
  if (_pendingPayouts.isEmpty) {
    return const SizedBox();
  }

  return Container(
    margin: const EdgeInsets.only(bottom: 20),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.orange.shade50,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.orange.shade200),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.card_giftcard, color: Colors.orange),
            SizedBox(width: 8),
            Text(
              "Родитель подготовил награды",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._pendingPayouts.map((p) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Icon(Icons.chevron_right),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "${p["amount"]} ${p["type"]}",
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        Row(
  children: [

    Expanded(
      child: ElevatedButton.icon(

        icon: const Icon(
          Icons.check_circle,
        ),

        label: const Text(
          "Подтверждаю",
        ),

        onPressed: () async {

          for (final payout
              in _pendingPayouts) {

            await _confirmPayout(
              payout["payout_id"],
            );
          }

          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "✅ Вы подтвердили получение наград!",
              ),
            ),
          );
        },
      ),
    ),

    const SizedBox(width: 12),

    Expanded(
      child: OutlinedButton.icon(

        icon: const Icon(
          Icons.close,
          color: Colors.red,
        ),

        label: const Text(
          "Отменить",
          style: TextStyle(
            color: Colors.red,
          ),
        ),

        onPressed: () async {

          for (final payout
              in _pendingPayouts) {

            await _cancelPayout(
              payout["payout_id"],
            );
          }
        },
      ),
    ),
  ],
)
      ],
    ),
  );
}

  // ============================================
  // ВКЛАДКА: Создать (родитель)
  // ============================================
  Widget _buildCreateTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(labelText: "Описание задания"),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _rewardController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Размер награды"),
        ),
        const SizedBox(height: 12),

        // Тип награды
        DropdownButtonFormField<int>(
          initialValue: _selectedRewardTypeId,
          decoration: const InputDecoration(labelText: "Тип награды"),
          items: [
            ..._rewardTypes.map((t) => DropdownMenuItem<int>(
                  value: t["id"],
                  child: Text("${t["icon"] ?? "🎁"} ${t["name"]}"),
                )),
            const DropdownMenuItem<int>(
              value: -1,
              child: Text("➕ Добавить новый"),
            ),
          ],
          onChanged: (v) async {
            if (v == -1) {
              final controller = TextEditingController();
              final name = await showDialog<String>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Новая награда"),
                  content: TextField(
                    controller: controller,
                    decoration: const InputDecoration(hintText: "Например: Минуты игры"),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Отмена"),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, controller.text),
                      child: const Text("Создать"),
                    ),
                  ],
                ),
              );
              if (name != null && name.isNotEmpty) {
                await ApiService.createRewardType(_familyId, name);
                await _loadData();
              }
              return;
            }
            setState(() {
              _selectedRewardTypeId = v;
            });
          },
        ),
        const SizedBox(height: 12),

        // Выбор ребёнка (с "Всем детям")
        DropdownButtonFormField<String>(
          initialValue: _allChildren ? "__ALL__" : _selectedChild,
          decoration: const InputDecoration(labelText: "Ребёнок"),
          items: [
            const DropdownMenuItem<String>(
              value: "__ALL__",
              child: Text("👨‍👩‍👧 Всем детям"),
            ),
            ..._children.map((child) {
              return DropdownMenuItem<String>(
                value: child["user_name"],
                child: Text("${child["avatar"] ?? "👦"} ${child["user_name"]}"),
              );
            }),
          ],
          onChanged: (v) {
            setState(() {
              _allChildren = (v == "__ALL__");
              _selectedChild = _allChildren ? null : v;
            });
          },
        ),
        const SizedBox(height: 12),

        // Повторение
        DropdownButtonFormField<String>(
          initialValue: _repeatMode,
          decoration: const InputDecoration(labelText: "Повторение"),
          items: const [
            DropdownMenuItem(value: "none", child: Text("Разовое")),
            DropdownMenuItem(value: "daily", child: Text("Ежедневное")),
            DropdownMenuItem(value: "weekly", child: Text("Еженедельное")),
            DropdownMenuItem(value: "weekdays", child: Text("По будням")),
            DropdownMenuItem(value: "weekends", child: Text("По выходным")),
          ],
          onChanged: (v) {
            setState(() {
              _repeatMode = v!;
            });
          },
        ),
        const SizedBox(height: 20),

        ElevatedButton(
          onPressed: _createTask,
          child: const Text("Создать"),
        ),

        const SizedBox(height: 24),
        const Text("Активные задания",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        // Список активных заданий
        ..._tasks
            .where((t) => t["status"] == "pending")
            .map((task) => Card(
                  child: ListTile(
                    title: Text(task["title"]),
                    subtitle: Text(
                      "${task["assigned_to"]} • ${task["reward_amount"]} ${task["reward_type"] ?? "₽"}",
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteTask(task["id"]),
                    ),
                  ),
                )),
      ],
    );
  }

  // ============================================
  // ВКЛАДКА: На проверке (родитель)
  // ============================================
  Widget _buildReviewTab() {
    final review = _tasks.where((t) => t["status"] == "done").toList();

    return ListView.builder(
      itemCount: review.length,
      itemBuilder: (context, index) {
        final task = review[index];
        return Card(
          child: ListTile(
            title: Text(task["title"]),
            subtitle: Text(
              "${task["assigned_to"]} • ${task["reward_amount"]} ${task["reward_type"] ?? "₽"}",
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  onPressed: () async {
                    await ApiService.approveTask(task["id"], _userName);
                    _loadData();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.orange),
                  onPressed: () async {
                    await ApiService.retryTask(task["id"], _userName);
                    _loadData();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  onPressed: () async {
                    await ApiService.rejectTask(task["id"], _userName);
                    _loadData();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================
  // ВКЛАДКА: Балансы (родитель)
  // ============================================
  Widget _buildBalancesTab() {
    if (_children.isEmpty) {
      return const Center(child: Text("Нет детей в семье"));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _children.length,
      itemBuilder: (context, index) {
        final child = _children[index];

       return FutureBuilder<Map<String, dynamic>>(
        future: ApiService.getChildBalance(_familyId, child["user_name"]),
       builder: (context, snapshot) {
          final data = snapshot.data;
          final balances = List<Map<String, dynamic>>.from(data?["balances"] ?? []);
          final pendingPayouts = List<Map<String, dynamic>>.from(data?["pending_payouts"] ?? []);
          final total = balances.fold<int>(0, (sum, b) => sum + ((b["amount"] as num).toInt()));

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 10),
                ],
              ),
              child: Column(
                children: [
                  // Аватар + имя
                  Row(
                    children: [
                      Text(child["avatar"] ?? "🧒",
                          style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(child["user_name"],
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Список балансов по типам
                  if (balances.isNotEmpty)
                    ...balances.map((b) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(b["type"] ?? "?",
                                  style: const TextStyle(fontSize: 16)),
                              Text("${b["amount"]}",
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ))
                  else
                    const Text("Нет накоплений",
                        style: TextStyle(color: Colors.grey)),

                  const SizedBox(height: 4),
                  Text("Всего: $total",
                      style: TextStyle(
                          fontSize: 16, color: Colors.green.shade700)),

                const SizedBox(height: 16),

if (pendingPayouts.isNotEmpty)

Container(

  padding: const EdgeInsets.all(14),

  decoration: BoxDecoration(

    color: Colors.orange.shade50,

    borderRadius:
        BorderRadius.circular(14),

    border: Border.all(
      color: Colors.orange.shade200,
    ),
  ),

  child: Column(

    crossAxisAlignment:
        CrossAxisAlignment.start,

    children: [

      const Row(

        children: [

          Icon(
            Icons.schedule,
            color: Colors.orange,
          ),

          SizedBox(width: 8),

          Text(
            "Ожидает подтверждения",
            style: TextStyle(
              fontWeight:
                  FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),

      const SizedBox(height: 12),

      ...pendingPayouts.map((p) {

        return Padding(

          padding:
              const EdgeInsets.only(
            bottom: 8,
          ),

          child: Row(

            children: [

              Expanded(
                child: Text(
                  "${p["amount_rub"]} ${p["type"]}",
                ),
              ),

              TextButton.icon(

                icon: const Icon(
                  Icons.close,
                  color: Colors.red,
                ),

                label: const Text(
                  "Отменить",
                  style: TextStyle(
                    color: Colors.red,
                  ),
                ),

                onPressed: () async {
                  final ok = await ApiService.cancelPayout(p["payout_id"]);
                  if (ok) {
                    setState(() {});
                  }
                },
              ),
            ],
          ),
        );
      }),
    ],
  ),
),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.payments),
                      label: const Text("Выплатить"),
                      onPressed: total <= 0
                          ? null
                          : () => _showPayoutDialog(
                              child["user_name"], balances),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ============================================
  // ВКЛАДКА: История (родитель)
  // ============================================
  Widget _buildHistoryTab() {
    var tasks = _tasks;

    if (_historyFilter != null) {
      tasks = tasks.where((t) => t["assigned_to"] == _historyFilter).toList();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: DropdownButtonFormField<String?>(
            initialValue: _historyFilter,
            decoration: const InputDecoration(labelText: "Фильтр по ребёнку"),
            items: [
              const DropdownMenuItem(value: null, child: Text("Все")),
              ..._children.map((child) => DropdownMenuItem(
                    value: child["user_name"],
                    child: Text(child["user_name"]),
                  )),
            ],
            onChanged: (v) => setState(() => _historyFilter = v),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return ListTile(
                title: Text(task["title"]),
                subtitle: Text("${task["assigned_to"]} • ${task["status"]}"),
                trailing: Text(
                    "${task["reward_amount"]} ${task["reward_type"] ?? "₽"}"),
              );
            },
          ),
        ),
      ],
    );
  }

  // ============================================
  // ВКЛАДКА: Мои задания (ребёнок)
  // ============================================
  Widget _buildChildTasksTab() {
    final tasks = _tasks
        .where((t) =>
            t["assigned_to"] == _userName && t["status"] == "pending")
        .toList();

    if (tasks.isEmpty) {
      return const Center(child: Text("Нет активных заданий"));
    }

    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Card(
          margin: const EdgeInsets.all(10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task["title"],
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                    "Награда: ${task["reward_amount"]} ${task["reward_type"] ?? "₽"}"),
                Text("От: ${task["created_by"]}"),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text("Я сделал!"),
                    onPressed: () async {
  final response = await http.post(
    Uri.parse("http://159.194.219.146:8000/tasks/done"),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "task_id": task["id"],
      "user_name": _userName,
    }),
  );
  
  if (!mounted) return;
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text("Код: ${response.statusCode}\nОтвет: ${response.body}"),
      duration: const Duration(seconds: 5),
    ),
  );
  
  if (response.statusCode == 200) {
    _loadData();
  }
},
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================
  // ВКЛАДКА: Мой счёт (ребёнок)
  // ============================================
  Widget _buildBalanceTab() {
    final history = _tasks
        .where((t) =>
            t["assigned_to"] == _userName &&
            (t["status"] == "approved" ||
                t["status"] == "done" ||
                t["status"] == "rejected"))
        .toList();

    final total =
        _childBalances.fold<int>(0, (sum, b) => sum + ((b["amount"] as num).toInt()));

    return Column(
      children: [

        _buildPendingPayoutCard(),
        const SizedBox(height: 20),
        // Карточка баланса
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Text("💰 Мой баланс",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              if (_childBalances.isNotEmpty)
                ..._childBalances.map((b) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(b["type"] ?? "?",
                              style: const TextStyle(fontSize: 16)),
                          Text("${b["amount"]}",
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ))
              else
                const Text("Нет накоплений",
                    style: TextStyle(color: Colors.grey)),

              if (_childBalances.isNotEmpty) ...[
                const Divider(height: 20),
                Text("Всего: $total",
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700)),
              ],
            ],
          ),
        ),

        // История
        Expanded(
          child: ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final task = history[index];
              return ListTile(
                title: Text(task["title"]),
                subtitle: Text(task["status"]),
                trailing: Text(
                    "${task["reward_amount"]} ${task["reward_type"] ?? "₽"}"),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    final isChild = _role == "child";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Хорошие дела"),
        bottom: TabBar(
          controller: _tabController,
          tabs: isChild
              ? const [
                  Tab(text: "Мои задания"),
                  Tab(text: "Мой счёт"),
                ]
              : const [
                  Tab(text: "Создать"),
                  Tab(text: "На проверке"),
                  Tab(text: "Балансы"),
                  Tab(text: "История"),
                ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: isChild
            ? [_buildChildTasksTab(), _buildBalanceTab()]
            : [
                _buildCreateTab(),
                _buildReviewTab(),
                _buildBalancesTab(),
                _buildHistoryTab()
              ],
      ),
    );
  }
}