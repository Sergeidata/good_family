import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/family_storage.dart';
import 'package:lottie/lottie.dart';
import '../services/cache_storage.dart';
import '../widgets/main_bottom_bar.dart';
import 'main_navigation_screen.dart';

class GardenScreen2 extends StatefulWidget {
  const GardenScreen2({
    super.key,
  });

  @override
  State<GardenScreen2> createState() =>
      _GardenScreen2State();
}

class _GardenScreen2State
    extends State<GardenScreen2> {
  bool _loading = true;

  int _level = 1;

  double _achievementProgress = 0.0;

  int _currentAchievements = 0;

  String _familyName = "Семья";

  DateTime? _lastUpdated;
  bool _fromCache = false;

  @override
  void initState() {
    super.initState();

    _loadGardenAndCheckLevel();
  }

  Future<void> _loadGarden() async {
  final family = await FamilyStorage.loadFamily();
  final familyId = family["family_id"];
  _familyName = family["family_name"] ?? "Семья";
  

  try {
    final garden = await ApiService.getGarden(familyId);
    if (garden != null) {
      _level = garden["level"] ?? 1;

      _achievementProgress = (garden["achievement_progress"] ?? 0.0).toDouble();
      await CacheStorage.save('garden_$familyId', {"level": _level});
      _lastUpdated = DateTime.now();
      _fromCache = false;
    } else {
      throw Exception("Garden data is null");
    }

    final allAchievements = await ApiService.getAchievements(familyId, "", null);
    final personalKeys = allAchievements
        .where((a) => a["user_name"] != _familyName && a["family_id"] == familyId)  // личные
        .map((a) => a["achievement_key"].toString())
        .toSet();
    final groupKeys = allAchievements
        .where((a) => a["user_name"] == _familyName && a["family_id"] == familyId)  // групповые
        .map((a) => a["achievement_key"].toString())
        .toSet();
    _currentAchievements = garden["achievements_count"] ?? 0;

    
    
    setState(() { _loading = false; });

  } catch (e) {
    final cache = await CacheStorage.load('garden_$familyId');
    if (cache != null) {
      _level = cache["data"]["level"] ?? 1;
      _lastUpdated = DateTime.tryParse(cache["updated_at"] ?? "");
      _fromCache = true;
    } else {
      _level = 1;
      _lastUpdated = null;
      _fromCache = true;
    }
  }

  
  
}

Future<void> _checkLevelUp() async {
  final family = await FamilyStorage.loadFamily();
  final familyId = family["family_id"];
  if (familyId == null) return;

  if (DateTime.now().weekday != DateTime.monday) return;

  final today = DateTime.now().toIso8601String().split("T")[0];

  // Проверяем дату последнего повышения с сервера
  final garden = await ApiService.getGarden(familyId);
  final lastLevelup = garden?["last_levelup"];
  if (lastLevelup != null && lastLevelup.toString().startsWith(today)) {
    return; // Уже повышали сегодня
  }

  final personalAchievements = await ApiService.getAchievements(familyId, "personal", null);
  final groupAchievements = await ApiService.getAchievements(familyId, "group", null);

  final personalKeys = personalAchievements
      .map((a) => a["achievement_key"].toString())
      .toSet();
  final groupKeys = groupAchievements
      .map((a) => a["achievement_key"].toString())
      .toSet();
  final uniqueCount = personalKeys.length + groupKeys.length;

  final currentLevel = garden?["level"] ?? _level;
  
  if (uniqueCount > currentLevel) {
    final nextLevel = (currentLevel + 1).clamp(1, 42);
    await ApiService.levelUpGarden(familyId, nextLevel);
    // После повышения перезагружаем сад
    await _loadGarden();
  }
}



  String getStageName(
    int level,
  ) {
    switch (level) {
      case 1:
        return "Росток";

      case 2:
        return "Первый лист";

      case 3:
        return "Первые листочки";

      case 4:
        return "Крепкий росток";

      case 5:
        return "Первые веточки";
      case 6:
        return "Маленький кустик";
      case 7:
        return "Куст";

      case 8:
        return "Первый цветок";

      case 9:
        return "Распускающийся куст";

      case 10:
        return "2 куста и бабочка";
      
      default:
        return "Росток";
    }
  }

  
  Future<void> _loadGardenAndCheckLevel() async {
  await _loadGarden();
  if (DateTime.now().weekday != DateTime.monday) return;
  await _checkLevelUp();
}

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Сад",
        ),
      ),
     body: _loading
    ? const Center(
        child: CircularProgressIndicator(),
      )
    : SafeArea(
        child: Column(
          children: [

            // САД

            SizedBox(
              width: double.infinity,
              height:
                  MediaQuery.of(context).size.height *
                      0.40,
              child: Lottie.asset(
                _getAnimationPath(_level),
                repeat: false,
                fit: BoxFit.cover,
                animate: true,
                onLoaded: (composition) {
                  // Анимация проиграется один раз
                },
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 20,
                ),
                child: Column(
                  children: [

                    // ИНФО КАРТОЧКА

                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.all(24),
                      decoration:
                          BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(
                          24,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 15,
                            offset:
                                const Offset(0, 5),
                          ),
                        ],
                      ),

                      child: Stack(
  children: [

    Positioned(
      top: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(
            Icons.info_outline_rounded,
            size: 22,
            color: Colors.grey,
          ),
          onPressed: () {
           showDialog(
  context: context,
  builder: (_) => AlertDialog(
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
            Icons.local_florist_rounded,
            color: Colors.green.shade600,
            size: 27,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            "Рост сада",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),

    content: Text(
      "Сад растет только по понедельникам по одному уровню за раз.",
      style: TextStyle(
        fontSize: 15,
        height: 1.45,
        color: Colors.grey.shade700,
      ),
    ),

    actions: [
      SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: const Text(
            "Понятно",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ],
  ),
);
          },
        ),
      ),
    ),

    Column(
      children: [
                      
                      
                      
                      
                      Column(
                        children: [

                          const Icon(
                            Icons.park,
                            size: 42,
                            color: Colors.green,
                          ),

                          const SizedBox(
                            height: 10,
                          ),

                          Text(
                            "Сад семьи $_familyName",
                            textAlign:
                                TextAlign.center,
                            style:
                                const TextStyle(
                              fontSize: 24,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          const SizedBox(
                            height: 20,
                          ),

                          Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 18,
                              vertical: 8,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  Colors.green
                                      .shade50,
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                50,
                              ),
                            ),
                            child: Text(
                              "Уровень $_level",
                              style:
                                  const TextStyle(
                                fontSize: 28,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          Text(
                            "${getStageName(_level)} "
                            "($_level/42)",
                            textAlign:
                                TextAlign.center,
                            style:
                                TextStyle(
                              fontSize: 20,
                              color:
                                  Colors.grey
                                      .shade700,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),

                          const SizedBox(
                            height: 25,
                          ),

                          if (_level < 42) ...[

                            Align(
                              alignment:
                                  Alignment
                                      .centerLeft,
                              child: Text(
                                "Прогресс развития сада",
                                style:
                                    TextStyle(
                                  fontSize:
                                      16,
                                  fontWeight:
                                      FontWeight
                                          .w600,
                                  color: Colors
                                      .grey
                                      .shade700,
                                ),
                              ),
                            ),

                            const SizedBox(
                              height: 10,
                            ),

                            ClipRRect(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                12,
                              ),
                              child:
                                  LinearProgressIndicator(
                                value:
                                    _progressValue(),
                                minHeight:
                                    16,
                                backgroundColor:
                                    Colors
                                        .grey
                                        .shade300,
                                color:
                                    Colors
                                        .green,
                              ),
                            ),

                            const SizedBox(
                              height: 18,
                            ),

                            Container(
                              width: double
                                  .infinity,
                              padding:
                                  const EdgeInsets
                                      .all(
                                16,
                              ),
                              decoration:
                                  BoxDecoration(
                                color:
                                    Colors
                                        .amber
                                        .shade50,
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  16,
                                ),
                              ),
                               child: Column(
  children: [
    RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
        children: [
          const TextSpan(text: "Для достижения следующего уровня всего необходимо заработать "),
          TextSpan(
            text: "$_level",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.green.shade700),
          ),
          const TextSpan(text: " уникальных достижений."),
        ],
      ),
    ),
    const SizedBox(height: 12),
    RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
        children: [
          const TextSpan(text: "Сейчас у вас "),
          TextSpan(
            text: "$_currentAchievements",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.blue.shade700),
          ),
          const TextSpan(text: " достижений + "),
          TextSpan(
            text: _achievementProgress.toStringAsFixed(2),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.orange.shade700),
          ),
          const TextSpan(text: " от хороших дел."),
        ],
      ),
    ),
    const SizedBox(height: 12),
    RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
        children: [
          const TextSpan(text: "Итого: "),
          TextSpan(
            text: "${(_currentAchievements + _achievementProgress).toStringAsFixed(2)}",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green.shade700),
          ),
        ],
      ),
    ),
  ],
),
                            )
                            
                          ] else ...[

                            Container(
                              width: double
                                  .infinity,
                              padding:
                                  const EdgeInsets
                                      .all(
                                18,
                              ),
                              decoration:
                                  BoxDecoration(
                                color:
                                    Colors
                                        .green
                                        .shade50,
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  16,
                                ),
                              ),
                              child: const Text(
                                "🌳 Сад достиг максимального уровня!\n\n"
                                  "Ваша семья заработала все достижения текущей версии.",
                                textAlign:
                                    TextAlign
                                        .center,
                                style:
                                    TextStyle(
                                  fontSize:
                                      18,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
      ]
                    ),

                    const SizedBox(
                      height: 30,
                    ),
                  ],
                ),
              ),
                  ]
            ),
              ),
            ),
            if (_lastUpdated != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _fromCache
                      ? "Последние данные: ${_lastUpdated!.day.toString().padLeft(2, '0')}.${_lastUpdated!.month.toString().padLeft(2, '0')}.${_lastUpdated!.year} ${_lastUpdated!.hour.toString().padLeft(2, '0')}:${_lastUpdated!.minute.toString().padLeft(2, '0')}"
                      : "Обновлено: ${_lastUpdated!.day.toString().padLeft(2, '0')}.${_lastUpdated!.month.toString().padLeft(2, '0')}.${_lastUpdated!.year} ${_lastUpdated!.hour.toString().padLeft(2, '0')}:${_lastUpdated!.minute.toString().padLeft(2, '0')}",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),

           
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

  String _getAnimationPath(int level) {
  switch (level) {
    case 1: return 'assets/animations/lvl1.json';
    case 2: return 'assets/animations/lvl2.json';
    case 3: return 'assets/animations/lvl3.json';
    case 4: return 'assets/animations/lvl4.json';
    case 5: return 'assets/animations/lvl5.json';
    case 6: return 'assets/animations/lvl6.json';
    case 7: return 'assets/animations/lvl7.json';
    case 8: return 'assets/animations/lvl8.json';
    case 9: return 'assets/animations/lvl9.json';
    case 10: return 'assets/animations/lvl10.json';
    case 11: return 'assets/animations/lvl11.json';
    default: return 'assets/animations/lvl1.json';
  }
}
  
  double _progressValue() {

  return (_level / 42)
      .clamp(
    0.0,
    1.0,
  );
}
}