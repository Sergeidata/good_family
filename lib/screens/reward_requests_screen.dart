import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/family_storage.dart';

class RewardRequestsScreen extends StatefulWidget {
  const RewardRequestsScreen({super.key});

  @override
  State<RewardRequestsScreen> createState() => _RewardRequestsScreenState();
}

class _RewardRequestsScreenState extends State<RewardRequestsScreen> {
  String _familyId = '';
  List<dynamic> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final family = await FamilyStorage.loadFamily();
    _familyId = family["family_id"] ?? '';
    final requests = await ApiService.getRewardRequests(_familyId);
    setState(() { _requests = requests; _loading = false; });
  }

  Future<void> _approve(int requestId) async {
    await ApiService.approveReward(requestId);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final pending = _requests.where((r) => r["status"] == "pending").toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Запросы на награды')),
      body: pending.isEmpty
          ? const Center(child: Text('Нет новых запросов'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: pending.length,
              itemBuilder: (ctx, i) {
                final req = pending[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Text(req["emoji"] ?? "🎁", style: const TextStyle(fontSize: 40)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(req["title"] ?? "", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('${req["child_name"]} хочет получить', style: TextStyle(color: Colors.grey.shade600)),
                              const SizedBox(height: 4),
                              Text('${req["cost_stars"]} ⭐', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check_circle, color: Colors.green, size: 32),
                              onPressed: () => _approve(req["id"]),
                            ),
                            IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.red, size: 28),
                                onPressed: () async {
                                  await ApiService.rejectReward(req["id"]);
                                  _loadData();
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}