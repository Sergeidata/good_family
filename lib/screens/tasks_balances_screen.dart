import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/family_storage.dart';
import '../widgets/main_bottom_bar.dart';
import 'main_navigation_screen.dart';

class TasksBalancesScreen extends StatefulWidget {
  const TasksBalancesScreen({super.key});

  @override
  State<TasksBalancesScreen> createState() => _TasksBalancesScreenState();
}

class _TasksBalancesScreenState extends State<TasksBalancesScreen> {
  String _familyId = '';
  String _userName = '';
  String _role = '';
  List<dynamic> _children = [];
  List<Map<String, dynamic>> _balances = [];
  List<Map<String, dynamic>> _pending = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final family = await FamilyStorage.loadFamily();
    _familyId = family['family_id'] ?? '';
    _userName = family['user_name'] ?? '';
    _role = family['role'] ?? '';

    if (_role == 'child') {
      final data = await ApiService.getChildBalance(_familyId, _userName);
      setState(() {
        _balances = List<Map<String, dynamic>>.from(data['balances'] ?? []);
        _pending = List<Map<String, dynamic>>.from(data['pending_payouts'] ?? []);
        _loading = false;
      });
    } else {
      final members = await ApiService.getMembers(_familyId);
      setState(() {
        _children = (members?['members'] ?? []).where((m) => m['role'] == 'child').toList();
        _loading = false;
      });
    }
  }

  Future<void> _showPayoutDialog(String childName, List<Map<String, dynamic>> balances) async {
    final selected = <int>{};

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text('Выплата — $childName'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...balances.map((b) {
                      final id = b['reward_type_id'] as int;
                      return CheckboxListTile(
                        value: selected.contains(id),
                        title: Text(b['type'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Доступно: ${b['amount']}'),
                        onChanged: (v) {
                          setDialogState(() {
                            if (v == true) {
                              selected.add(id);
                            } else {
                              selected.remove(id);
                            }
                          });
                        },
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await ApiService.createPayout(_familyId, childName, rewardTypeIds: selected.toList());
                    Navigator.pop(ctx);
                    _loadData();
                  },
                  child: const Text('Выплатить выбранное'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await ApiService.createPayout(_familyId, childName);
                    Navigator.pop(ctx);
                    _loadData();
                  },
                  child: const Text('Выплатить всё'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_role == 'child') {
      return _buildChildBalance();
    }

    return _buildParentBalances();
  }

  Widget _buildChildBalance() {
    final total = _balances.fold<int>(0, (sum, b) => sum + ((b['amount'] as num).toInt()));

    return Scaffold(
      appBar: AppBar(title: const Text('Мой счёт')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)],
              ),
              child: Column(
                children: [
                  const Text('💰 Мой баланс', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (_balances.isNotEmpty)
                    ..._balances.map((b) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(b['type'] ?? '', style: const TextStyle(fontSize: 16)),
                              Text('${b['amount']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ))
                  else
                    const Text('Нет накоплений', style: TextStyle(color: Colors.grey)),
                  if (total > 0) ...[
                    const Divider(height: 24),
                    
                  ],
                ],
              ),
            ),
            if (_pending.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
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
                        Text('Родитель подготовил награды', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._pending.map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.chevron_right, size: 18),
                              const SizedBox(width: 6),
                              Text('${p['amount']} ${p['type']}', style: const TextStyle(fontSize: 16)),
                            ],
                          ),
                        )),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          for (final p in _pending) {
                            await ApiService.confirmPayout(p['payout_id'], _userName);
                          }
                          _loadData();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('✅ Вы подтвердили получение наград!')),
                            );
                          }
                        },
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Подтверждаю получение'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: MainBottomBar(
  currentIndex: null,
  onTap: (index) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => MainNavigationScreen(
          initialIndex: index,
        ),
      ),
      (_) => false,
    );
  },
),
    );
  }

  Widget _buildParentBalances() {
    return Scaffold(
      appBar: AppBar(title: const Text('Балансы')),
      body: _children.isEmpty
          ? const Center(child: Text('Нет детей в семье', style: TextStyle(fontSize: 16, color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _children.length,
              itemBuilder: (context, index) {
                final child = _children[index];
                final childName = child['user_name'] ?? '';

                return FutureBuilder<Map<String, dynamic>>(
                  future: ApiService.getChildBalance(_familyId, childName),
                  builder: (context, snapshot) {
                    final data = snapshot.data;
                    final balances = List<Map<String, dynamic>>.from(data?['balances'] ?? []);
                    final pending = List<Map<String, dynamic>>.from(data?['pending_payouts'] ?? []);
                    final total = balances.fold<int>(0, (sum, b) => sum + ((b['amount'] as num).toInt()));

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text(child['avatar'] ?? '🧒', style: const TextStyle(fontSize: 32)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(childName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (balances.isNotEmpty)
                              ...balances.map((b) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 5),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(b['type'] ?? '', style: const TextStyle(fontSize: 16)),
                                        Text('${b['amount']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ))
                            else
                              const Text('Нет накоплений', style: TextStyle(color: Colors.grey)),
                            if (total > 0) ...[
                              const Divider(height: 24),
                              
                            ],
                            if (pending.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.orange.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.schedule, color: Colors.orange, size: 18),
                                        SizedBox(width: 8),
                                        Text('Ожидает подтверждения', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    ...pending.map((p) => Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text('${p['amount']} ${p['type']}', style: const TextStyle(fontSize: 14)),
                                              ),
                                              TextButton(
                                                onPressed: () async {
                                                  await ApiService.cancelPayout(p['payout_id']);
                                                  setState(() {});
                                                },
                                                child: const Text('Отменить', style: TextStyle(color: Colors.red, fontSize: 13)),
                                              ),
                                            ],
                                          ),
                                        )),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: total <= 0 && pending.isEmpty
                                    ? null
                                    : () => _showPayoutDialog(childName, balances),
                                icon: const Icon(Icons.payments, size: 20),
                                label: const Text('Выплатить'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            bottomNavigationBar: MainBottomBar(
  currentIndex: null,
  onTap: (index) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => MainNavigationScreen(
          initialIndex: index,
        ),
      ),
      (_) => false,
    );
  },
),
    );
  }
}