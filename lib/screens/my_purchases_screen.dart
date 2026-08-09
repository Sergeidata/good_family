import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/family_storage.dart';

class MyPurchasesScreen extends StatefulWidget {
  const MyPurchasesScreen({super.key});

  @override
  State<MyPurchasesScreen> createState() => _MyPurchasesScreenState();
}

class _MyPurchasesScreenState extends State<MyPurchasesScreen> {
  String _familyId = '';
  String _userName = '';
  List<dynamic> _purchases = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final family = await FamilyStorage.loadFamily();
    _familyId = family["family_id"] ?? '';
    _userName = family["user_name"] ?? '';

    final requests = await ApiService.getRewardRequests(_familyId);
    setState(() {
      _purchases = requests.where((r) => r["child_name"] == _userName).toList();
      _loading = false;
    });
  }

  Future<void> _confirm(int requestId) async {
    await ApiService.confirmReward(requestId);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final pending = _purchases.where((r) => r["status"] == "approved").toList();
    final completed = _purchases.where((r) => r["status"] == "completed" || r["status"] == "rejected").toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Мои покупки')),
      body: _purchases.isEmpty
          ? const Center(child: Text('Нет покупок'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (pending.isNotEmpty) ...[
                  const Text('Ожидают получения', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...pending.map((p) => _buildPurchaseCard(p, canConfirm: true)),
                  const SizedBox(height: 20),
                ],
                if (completed.isNotEmpty) ...[
                  const Text('История', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...completed.map((p) => _buildPurchaseCard(p, canConfirm: false)),
                ],
              ],
            ),
    );
  }

  Widget _buildPurchaseCard(dynamic p, {required bool canConfirm}) {
    final status = p["status"] ?? "";
    String statusText;
    Color statusColor;
    switch (status) {
      case "pending": statusText = "Ожидает"; statusColor = Colors.orange; break;
      case "approved": statusText = "Одобрено"; statusColor = Colors.green; break;
      case "completed": statusText = "Получено"; statusColor = Colors.blue; break;
      case "rejected": statusText = "Отклонено"; statusColor = Colors.red; break;
      default: statusText = status; statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Text(p["emoji"] ?? "🎁", style: const TextStyle(fontSize: 36)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p["title"] ?? "", style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${p["cost_stars"]} ⭐', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ),
            if (canConfirm)
              ElevatedButton(
                onPressed: () => _confirm(p["id"]),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Получил!'),
              ),
          ],
        ),
      ),
    );
  }
}