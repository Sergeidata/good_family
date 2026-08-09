import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/family_storage.dart';

class RewardRequestsScreen extends StatefulWidget {
  const RewardRequestsScreen({super.key});

  @override
  State<RewardRequestsScreen> createState() => _RewardRequestsScreenState();
}

class _RewardRequestsScreenState extends State<RewardRequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _familyId = '';
  List<dynamic> _requests = [];
  List<dynamic> _balances = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final family = await FamilyStorage.loadFamily();
    _familyId = family["family_id"] ?? '';

    final requests = await ApiService.getRewardRequests(_familyId);

    // Балансы детей
    final members = await ApiService.getMembers(_familyId);
    final children = (members?["members"] ?? []).where((m) => m["role"] == "child").toList();
    List<Map<String, dynamic>> balances = [];
    for (final child in children) {
      final data = await ApiService.getChildBalance(_familyId, child["user_name"]);
      balances.add({
        "name": child["user_name"],
        "avatar": child["avatar"] ?? "👦",
        "stars": data["stars"] ?? 0,
      });
    }

    setState(() {
      _requests = requests;
      _balances = balances;
      _loading = false;
    });
  }

  Future<void> _approve(int requestId) async {
    await ApiService.approveReward(requestId);
    _loadData();
  }

  Future<void> _reject(int requestId) async {
    await ApiService.rejectReward(requestId);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Балансы и запросы'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Запросы'),
            Tab(text: 'Балансы'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRequestsTab(),
          _buildBalancesTab(),
        ],
      ),
    );
  }

  Widget _buildRequestsTab() {
    final pending = _requests.where((r) => r["status"] == "pending").toList();

    if (pending.isEmpty) {
      return const Center(child: Text('Нет новых запросов'));
    }

    return ListView.builder(
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
                      onPressed: () => _reject(req["id"]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBalancesTab() {
    if (_balances.isEmpty) {
      return const Center(child: Text('Нет детей'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _balances.length,
      itemBuilder: (ctx, i) {
        final b = _balances[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Text(b["avatar"], style: const TextStyle(fontSize: 36)),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(b["name"], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                Text('${b["stars"]} ⭐', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amber)),
              ],
            ),
          ),
        );
      },
    );
  }
}