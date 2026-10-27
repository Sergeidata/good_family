import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/family_storage.dart';
import '../widgets/emoji_picker.dart';
import '../widgets/main_bottom_bar.dart';
import 'main_navigation_screen.dart';
import 'my_purchases_screen.dart';
import '../widgets/loading_dots.dart';

class RewardShopScreen extends StatefulWidget {
  final bool childMode;
  final String? childName;

  const RewardShopScreen({
    super.key,
    this.childMode = false,
    this.childName,
  });

  @override
  State<RewardShopScreen> createState() => _RewardShopScreenState();
}

class _RewardShopScreenState extends State<RewardShopScreen> {
  String _familyId = '';
  List<dynamic> _items = [];

  List<dynamic> _requests = [];

  String _userName = '';
  String _role = '';

  int _balance = 0;

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
  _role = family["role"] ?? '';

  final items = await ApiService.getRewardShop(_familyId);

  final requests =
      await ApiService.getRewardRequests(_familyId);

  int balance = 0;

  if (_role == "child") {
    final data = await ApiService.getChildBalance(
      _familyId,
      _userName,
    );

    balance = data["stars"] ?? 0;
  }

  setState(() {
    _items = items;
    _requests = requests;
    _balance = balance;
    _loading = false;
  });
}


Map<String, dynamic>? _requestForReward(int rewardId) {
  try {
    return _requests.firstWhere(
      (e) =>
          e["reward_id"] == rewardId &&
          e["child_name"] == _userName &&
          e["status"] != "completed",
    );
  } catch (_) {
    return null;
  }
}

  Future<void> _showRewardSheet({Map<String, dynamic>? item}) async {
  final titleCtrl =
      TextEditingController(text: item?["title"] ?? "");

  final costCtrl = TextEditingController(
    text: item == null
        ? "100"
        : item["cost_stars"].toString(),
  );

  final _descCtrl = TextEditingController(text: item?["description"] ?? "");
  
  
const List<String> _rewardColors = [
  "#FFE0B2", // оранжевый
  "#C8E6C9", // зелёный
  "#BBDEFB", // голубой
  "#E1BEE7", // фиолетовый
  "#FFCDD2", // красный
  "#B2EBF2", // бирюзовый
];

String _selectedColorHex = "#FFF4E5";

Color _colorFromHex(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  return Color(int.parse('FF$cleaned', radix: 16));
}


  String selectedEmoji =
      item?["emoji"] ?? "🎁";

  bool expanded = false;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {

          return Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom:
                  MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),

            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(30),
              ),
            ),

            child: SingleChildScrollView(

              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    item == null
                        ? "Новая награда"
                        : "Редактирование",

                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 24),

                  TextField(
                    controller: titleCtrl,
                    maxLength: 25,
                    decoration: InputDecoration(
                      labelText: "Название",
                      counterText: "",
                      prefixIcon: const Icon(Icons.card_giftcard),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),

                  const SizedBox(height: 18),

                      TextField(
                        controller: _descCtrl,
                        maxLength: 80,
                        decoration: InputDecoration(
                          labelText: "Описание (необязательно)",
                          hintText: "Например: Модель телефона",
                          prefixIcon: const Icon(Icons.info_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          counterText: "",
                        ),
                      ),

                  const SizedBox(height: 18),

                  TextField(
                    controller: costCtrl,
                    keyboardType:
                        TextInputType.number,

                    decoration: InputDecoration(
                      labelText:
                          "Стоимость",

                      prefixIcon: Padding(
  padding: const EdgeInsets.only(left: 12),
  child: Stack(
    alignment: Alignment.center,
    children: const [
      Icon(Icons.circle, size: 25, color: Colors.amber),
      Icon(Icons.star, size: 13, color: Colors.white),
    ],
  ),
),
  

                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  const Text(
                    "Иконка",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),

                  const SizedBox(height: 12),

                  EmojiPicker(
                    selected: selectedEmoji,
                    expanded: expanded,
                    onSelected: (emoji) {
                      setModalState(() {
                        selectedEmoji = emoji;
                      });
                    },
                  ),

                  const SizedBox(height: 8),

                  Center(
                    child: TextButton.icon(
                      onPressed: () {

                        setModalState(() {
                          expanded = !expanded;
                        });

                      },

                      icon: Icon(
                        expanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                      ),

                      label: Text(
                        expanded
                            ? "Скрыть"
                            : "Показать ещё",
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),
const Text("Цвет карточки", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
const SizedBox(height: 12),
StatefulBuilder(
  builder: (context, setModalState) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: _rewardColors.map((hex) {
      final isSelected = _selectedColorHex == hex;
      return GestureDetector(
        onTap: () => setModalState(() => _selectedColorHex = hex),
        child: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: _colorFromHex(hex),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSelected ? Colors.black87 : Colors.transparent, width: 2),
          ),
          child: isSelected ? const Icon(Icons.check, size: 20, color: Colors.black87) : null,
        ),
      );
    }).toList(),
  ),
),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,

                    height: 52,

                    child: ElevatedButton(

                      style: ElevatedButton.styleFrom(
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                        ),
                      ),

                      onPressed: () async {

                   if (item == null) {
                    await ApiService.createReward(_familyId, titleCtrl.text, selectedEmoji, int.parse(costCtrl.text), colorHex: _selectedColorHex, description: _descCtrl.text.trim()
                    );
                  } else {
                    await ApiService.updateReward(
                      item["id"],
                      titleCtrl.text.trim(),
                      selectedEmoji,
                      int.parse(costCtrl.text),
                      colorHex: _selectedColorHex,
                      description: _descCtrl.text.trim(), 
                    );
                  }

                        if (context.mounted) {
                          Navigator.pop(ctx);
                        }

                        _loadData();

                      },

                      child: Text(
                        item == null
                            ? "Создать награду"
                            : "Сохранить изменения",
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
  );
}

 

Widget _buildShopSummary() {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.green.shade400,
          Colors.green.shade600,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Center(
            child: Text(
              "⭐",
              style: TextStyle(fontSize: 30),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Наград в магазине: ${_items.length}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Добавляйте призы и редактируйте их в пару касаний.",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Color _colorFromHex(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  return Color(int.parse('FF$cleaned', radix: 16));
}


Future<void> _buyReward(Map<String, dynamic> item) async {
  final cost = (item["cost_stars"] ?? 0) as int;

  if (_balance < cost) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Не хватает монет"),
      ),
    );
    return;
  }

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
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.shopping_bag_outlined,
            color: Colors.orange.shade600,
            size: 27,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            "Купить награду?",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),

    content: Text(
      "Купить «${item["title"]}» за $cost 🪙?",
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
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "Купить",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  ),
) ?? false;

  if (!confirmed) return;

  final childName = widget.childName ??
      (await FamilyStorage.loadFamily())["user_name"] ??
      '';

  final ok = await ApiService.buyReward(
    _familyId,
    childName,
    item["id"],
  );

  if (!ok) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Не удалось оформить покупку"),
      ),
    );
    return;
  }

  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("Покупка отправлена на подтверждение"),
    ),
  );

  _loadData();
}

Widget _buildChildHeader() {
  return Container(
    margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.green.shade400, Colors.green.shade600],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 8)),
      ],
    ),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(child: Text("🪙", style: TextStyle(fontSize: 30))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Мои монеты: $_balance 🪙",
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text("Выбирайте награды и копите на то, что нравится.",
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MyPurchasesScreen()));
            },
            icon: const Icon(Icons.receipt_long, color: Colors.white, size: 18),
            label: const Text('Мои покупки', style: TextStyle(color: Colors.white)),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
             ),
        ),
        
      ],
    ),
  );
}


 @override
Widget build(BuildContext context) {
  if (_loading) return const Scaffold(body: Center(child: LoadingDots()));

  return Scaffold(
    appBar: AppBar(
      title: Text(widget.childMode ? 'Магазин наград' : 'Магазин наград'),
    ),

    
    floatingActionButton: widget.childMode
        ? null
        : FloatingActionButton(
            onPressed: () => _showRewardSheet(),
            child: const Icon(Icons.add),
          ),
    body: Column(
      children: [
        if (widget.childMode) _buildChildHeader(),
        if (!widget.childMode) _buildShopSummary(),
        Expanded(
          child: _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 54, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        widget.childMode ? 'Пока нет наград' : 'Нет наград в магазине',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                      ),
                      if (!widget.childMode) ...[
                        const SizedBox(height: 8),
                        Text('Нажмите +, чтобы добавить первую награду', style: TextStyle(color: Colors.grey.shade500)),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                  itemCount: _items.length,
                  itemBuilder: (ctx, i) {
                    final item = _items[i];
                    final accent = _colorFromHex(item["color_hex"] ?? "#FFF4E5").withOpacity(0.7);
                    final cost = (item["cost_stars"] ?? 0) as int;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: _colorFromHex(item["color_hex"] ?? "#FFF4E5"),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(28),
                        onTap: widget.childMode
                            ? () => _buyReward(item)
                            : () => _showRewardSheet(item: item),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 72, height: 72,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(color: accent.withOpacity(0.18), width: 1.5),
                                  ),
                                  child: Center(
                                    child: Text(item["emoji"] ?? "🎁", style: const TextStyle(fontSize: 38)),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                     Text(
                                    item["title"] ?? "",
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.1),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                      if ((item["description"] ?? "").toString().isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Text(
                                            item["description"],
                                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.3),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                              const SizedBox(height: 18),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.75),
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                    child: Text("$cost 🪙", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: const Color.fromARGB(202, 73, 73, 73))),
                                  ),
                                  if (!widget.childMode)
                                    InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () async {
                                        final ok = await showDialog<bool>(
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
            Icons.delete_outline_rounded,
            color: Colors.red.shade500,
            size: 27,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            "Удалить награду?",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),

    content: Text(
      "Удалить «${item["title"]}» из магазина?",
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
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "Удалить",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  ),
) ?? false;
                                        if (!ok) return;
                                        await ApiService.deleteReward(item["id"]);
                                        _loadData();
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: Icon(Icons.delete_outline, size: 22, color: Colors.red.shade400),
                                      ),
                                    ),
                                ],
                              ),
                              if (widget.childMode) ...[
  const SizedBox(height: 14),

  SizedBox(
    width: double.infinity,
    height: 50,
    child: ElevatedButton.icon(
      onPressed: cost <= _balance
          ? () => _buyReward(item)
          : null,

      icon: Icon(
        cost <= _balance
            ? Icons.shopping_bag_outlined
            : Icons.lock_outline_rounded,
        size: 21,
      ),

      label: Text(
        cost <= _balance
            ? "Купить за $cost 🪙"
            : "Не хватает звёзд",
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),

      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade500,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade200,
        disabledForegroundColor: Colors.grey.shade500,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    ),
  ),
],

                              
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
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