import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/family_storage.dart';
import 'package:lottie/lottie.dart';
import '../services/cache_storage.dart';

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

  String _familyName = "Семья";

  DateTime? _lastUpdated;
  bool _fromCache = false;

  @override
  void initState() {
    super.initState();

    _loadGardenAndCheckLevel();
  }

  Future<void> _loadGarden() async {

  final family =
      await FamilyStorage.loadFamily();

  final familyId =
      family["family_id"];

  _familyName =
      family["family_name"] ?? "Семья";

  try {

    final garden =
        await ApiService.getGarden(
      familyId,
    );

    if (garden != null) {

      _level =
          garden["level"] ?? 1;

      await CacheStorage.save(
        'garden_$familyId',
        {
          "level": _level,
        },
      );

      _lastUpdated =
          DateTime.now();

      _fromCache = false;

    } else {

      throw Exception(
        "Garden data is null",
      );
    }

  } catch (e) {

    final cache =
        await CacheStorage.load(
      'garden_$familyId',
    );

    if (cache != null) {

      _level =
          cache["data"]["level"] ?? 1;

      _lastUpdated =
          DateTime.tryParse(
        cache["updated_at"] ?? "",
      );

      _fromCache = true;

    } else {

      _level = 1;

      _lastUpdated = null;

      _fromCache = true;
    }
  }

  if (mounted) {

    setState(() {
      _loading = false;
    });
  }
}

  Future<void> _checkLevelUp() async {
  final family = await FamilyStorage.loadFamily();
  final familyId = family["family_id"];
  if (familyId == null) return;

  // Проверяем что сегодня понедельник
  if (DateTime.now().weekday != DateTime.monday) return;

  // Проверяем что сегодня ещё не повышали
  final today = DateTime.now().toIso8601String().split("T")[0];
  final lastLevelUp = await CacheStorage.load('garden_levelup_$familyId');
  if (lastLevelUp != null && lastLevelUp["data"] != null && lastLevelUp["data"]["date"] == today) return;

  final achievements = await ApiService.getAchievements(familyId, "", null);
  if (achievements.isEmpty) return;

  final uniqueCount = achievements.map((e) => e["achievement_key"] as String).toSet().length;




  // Повышаем только если уникальных ачивок больше текущего уровня
  if (uniqueCount > _level) {
    final nextLevel = (_level + 1).clamp(1, 42);
    await ApiService.levelUpGarden(familyId, nextLevel);
    await CacheStorage.save('garden_levelup_$familyId', {"date": today});
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

      default:
        return "Росток";
    }
  }

  

  String _nextLevelRequirement() {

  if (_level >= 42) {

    return
        "Сад достиг максимального уровня в текущей версии!";
  }

  final requiredAchievements =
      _level;

  return
      "Для достижения следующего уровня сада всего должно быть заработано "
      "$requiredAchievements уникальных достижений";
}

  Future<void> _loadGardenAndCheckLevel() async {
    await _loadGarden();
    if (DateTime.now().weekday != 1) return;
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
                repeat: true,
                fit: BoxFit.cover,
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

                      child: Column(
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
                              child: Text(
                                _nextLevelRequirement(),
                                textAlign:
                                    TextAlign
                                        .center,
                                style:
                                    const TextStyle(
                                  fontSize:
                                      16,
                                  height:
                                      1.4,
                                ),
                              ),
                            ),

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
                    ),

                    const SizedBox(
                      height: 30,
                    ),
                  ],
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