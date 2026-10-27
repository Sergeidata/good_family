import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/family_storage.dart';
import '../utils/app_utils.dart';
import '../widgets/loading_dots.dart';

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

    // Балансы детей — параллельно, без N+1.
    final List<Map<String, dynamic>> balances = await Future.wait(
      children.map(
        (child) async {
          final data = await ApiService.getChildBalance(_familyId, child["user_name"]);
          return <String, dynamic>{
            "name": child["user_name"],
            "avatar": child["avatar"] ?? "👦",
            "stars": data["stars"] ?? 0,
          };
        },
      ),
    );

    setState(() {
      _requests = requests;
      _balances = balances;
      _loading = false;
    });
  }

  Future<void> _approve(int requestId) async {
  final confirmed = await showDialog<bool>(
  context: context,
  builder: (ctx) => AlertDialog(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
    titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
    contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
    actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),

    title: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.card_giftcard_rounded,
            color: Colors.green.shade600,
            size: 27,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            "Выдать награду?",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),

    content: Text(
      "Ребёнок получит уведомление о том, что награда одобрена.",
      style: TextStyle(
        fontSize: 15,
        height: 1.45,
        color: Colors.grey.shade700,
      ),
    ),

    actions: [
      Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(
                    color: Colors.grey.shade300,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "Отмена",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "Выдать",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  ),
);
  if (confirmed != true) return;
  await ApiService.approveReward(requestId);
  _loadData();
}

Future<void> _reject(int requestId) async {
  final confirmed = await showDialog<bool>(
  context: context,
  builder: (ctx) => AlertDialog(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
    titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
    contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
    actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),

    title: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.cancel_outlined,
            color: Colors.red.shade500,
            size: 27,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            "Отклонить запрос?",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),

    content: Text(
      "Монеты вернутся ребёнку на баланс.",
      style: TextStyle(
        fontSize: 15,
        height: 1.45,
        color: Colors.grey.shade700,
      ),
    ),

    actions: [
      Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(
                    color: Colors.grey.shade300,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "Отмена",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade500,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "Да",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  ),
);
  if (confirmed != true) return;
  await ApiService.rejectReward(requestId);
  _loadData();
}

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: LoadingDots()));

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
  return const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.card_giftcard_outlined,
          size: 72,
          color: Colors.grey,
        ),
        SizedBox(height: 16),
        Text(
          'Нет новых запросов',
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey,
          ),
        ),
      ],
    ),
  );
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
                     Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    const Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.circle, size: 22, color: Colors.amber),
        Icon(Icons.star, size: 13, color: Colors.white),
      ],
    ),
    const SizedBox(width: 4),
    Text('${req["cost_stars"]}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
  ],
),
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
  return const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.account_balance_wallet_outlined,
          size: 72,
          color: Colors.grey,
        ),
        SizedBox(height: 16),
        Text(
          'Нет детей',
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Добавьте ребёнка в семью',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    ),
  );
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
                (b["avatar"] ?? "").toString().startsWith('/uploads/')
    ? CircleAvatar(
  radius: 22,
  backgroundImage: NetworkImage(
    Uri.encodeFull(avatarUrl(b["avatar"])),
  ),
)
    : Text(b["avatar"] ?? "👦", style: const TextStyle(fontSize: 36)),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(b["name"], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
               Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    const Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.circle, size: 25, color: Colors.amber),
        Icon(Icons.star, size: 13, color: Colors.white),
      ],
    ),
    const SizedBox(width: 6),
    Text('${b["stars"]}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amber)),
  ],
),
              ],
            ),
          ),
        );
      },
    );
  }
}