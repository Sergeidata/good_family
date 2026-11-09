/*******************************************************************************************
 * GOOD FAMILY — ДАШБОРД АНАЛИТИКИ В GOOGLE SHEETS
 * -----------------------------------------------------------------------------------------
 * v2 (09.11.2026). ГЛАВНОЕ ОТЛИЧИЕ ОТ v1: НА ЛИСТАХ НЕТ НИ ОДНОЙ ФОРМУЛЫ.
 * Все значения (KPI, проценты, воронка, проверки, текст) считаются в JavaScript и
 * записываются как значения (setValue/setValues). Поэтому локаль таблицы и разделители
 * аргументов больше не могут дать #ERROR!. Данные обновляются целиком каждый час.
 *
 * Источник данных: http://89.108.66.36/export_stats (CSV, 5 срезов, UrlFetchApp).
 * Секрет хранится в свойствах скрипта (PropertiesService), на листах его нет.
 *
 * КАК ЗАПУСТИТЬ (владельцу, без терминала и git):
 *   1. Таблица → Расширения → Apps Script.
 *   2. Удалить старый код в Code.gs, вставить этот целиком, сохранить (💾).
 *   3. Вернуться в таблицу, обновить страницу (F5).
 *   4. Меню «Аналитика Good Family» → «Настроить / обновить дашборд».
 *   5. Вставить секрет аналитики (один раз). Готово: обновление каждый час.
 *
 * Если в книге остались #ERROR! от старой версии — просто запустите «Настроить / обновить
 * дашборд» ещё раз: скрипт снимает защиты, очищает листы и пишет значения заново.
 *******************************************************************************************/

var CFG = {
  SOURCE_URL: 'http://89.108.66.36/export_stats',
  SECRET_PROPERTY: 'EXPORT_STATS_SECRET',
  HISTORY_DAYS: 90,
  SHEET: {
    dashboard:    'Дашборд',
    summary:      'Сырые данные',
    features:     'Функции',
    history:      'История',
    achievements: 'Достижения',
    apps:         'Приложения',
    service:      '_Служебный'
  },
  C: {
    dark:'#1B5E20', green:'#2E7D32', lightGreen:'#E8F5E9',
    blue:'#1565C0', lightBlue:'#E3F2FD',
    amber:'#EF6C00', lightAmber:'#FFF8E1',
    purple:'#6A1B9A', lightPurple:'#F3E5F5',
    section:'#ECEFF1', sectionText:'#263238', head:'#CFD8DC',
    border:'#CFD8DC', text:'#212121', muted:'#546E7A',
    red:'#C62828', lightRed:'#FFEBEE', white:'#FFFFFF', band:'#F7F9FA'
  }
};

// ---------------------------------------------------------------------------------------
// Меню
// ---------------------------------------------------------------------------------------
// onOpen вызывается в двух случаях:
//   1. как простой триггер при открытии таблицы — здесь UI-контекст ЕСТЬ,
//      меню появится;
//   2. при установке/запуске из редактора Apps Script — UI-контекста НЕТ,
//      и SpreadsheetApp.getUi() бросает "Cannot call SpreadsheetApp.getUi()
//      from this context".
// Поэтому обязательно try/catch: без него ошибка всплывает в «Выполнениях»
// и пугает владельца, хотя меню при обычном открытии всё равно появится.
function onOpen() {
  try {
    SpreadsheetApp.getUi()
      .createMenu('Аналитика Good Family')
      .addItem('Настроить / обновить дашборд', 'setupDashboard')
      .addItem('Обновить данные сейчас', 'refreshDashboard')
      .addItem('Включить ежечасное обновление', 'installTrigger')
      .addItem('Как это работает (инструкция)', 'showInstructions')
      .addToUi();
  } catch (e) {
    // Нет UI-контекста (установка триггера, запуск из редактора) — это норма.
    Logger.log('onOpen: пропущено меню (нет UI-контекста): ' + e);
  }
}

/**
 * Ручная установка меню — на случай, если при открытии таблицы его нет.
 * Запускается ИЗ РЕДАКТОРА (там нет UI), поэтому выполнять пункт нужно
 * из меню таблицы. Дублирующий пункт ставит setupDashboard через installMenu().
 */
function installMenu() {
  try {
    SpreadsheetApp.getUi()
      .createMenu('Аналитика Good Family')
      .addItem('Настроить / обновить дашборд', 'setupDashboard')
      .addItem('Обновить данные сейчас', 'refreshDashboard')
      .addItem('Включить ежечасное обновление', 'installTrigger')
      .addItem('Как это работает (инструкция)', 'showInstructions')
      .addToUi();
  } catch (e) {
    Logger.log('installMenu: нет UI-контекста: ' + e);
  }
}

function showInstructions() {
  alert_('Как это работает', [
    '1. Скрипт сам забирает данные с сервера аналитики (за вчера, UTC).',
    '2. Каждый час он обновляет листы «Сырые данные», «Функции», «История»,',
    '   «Достижения», «Приложения» и пересчитывает «Дашборд».',
    '3. На листах нет формул — только значения. Поэтому #ERROR! не появляются.',
    '4. Если цифры не обновились: меню → «Обновить данные сейчас».',
    '5. Дата и статус последнего обновления — на скрытом листе «_Служебный».',
    '',
    'Не удаляйте и не переименовывайте листы: «Дашборд», «Сырые данные»,',
    '«Функции», «История», «Достижения», «Приложения», «_Служебный».'
  ].join('\n'));
}

// ---------------------------------------------------------------------------------------
// Точки входа
// ---------------------------------------------------------------------------------------
// Все точки входа вызываются из меню таблицы (UI-контекст есть), но могут быть
// запущены и из редактора Apps Script (UI-контекста НЕТ). Поэтому каждое обращение
// к SpreadsheetApp.getUi() обёрнуто: при отсутствии UI пишем в Logger и продолжаем.
function safeUi_() {
  try {
    return SpreadsheetApp.getUi();
  } catch (e) {
    Logger.log('UI-контекст недоступен: ' + e);
    return null;
  }
}

function alert_(title, message) {
  var ui = safeUi_();
  if (ui) {
    try { ui.alert(title, message, ui.ButtonSet.OK); } catch (ignore) {}
  }
  // В любом случае дублируем в лог — виден в «Выполнениях» и в логах.
  Logger.log('[' + title + '] ' + message);
}

function setupDashboard() {
  var success = true;
  var message = '';

  try {
    getSecret_(true);                 // при первом запуске спросит секрет и сохранит его
  } catch (e) {
    alert_('Нужен секрет', e.message);
    return;
  }

  try {
    renderAll_();
    installTrigger(true);
  } catch (e) {
    success = false;
    message = e.message;
    try { installTrigger(true); } catch (ignore) {}
  }

  alert_(
    success ? 'Готово' : 'Дашборд собран с ошибкой',
    success
      ? 'Дашборд собран. Данные обновляются каждый час автоматически.'
      : 'Оформление и структура готовы, но данные не загрузились:\n\n' + message +
        '\n\nПроверьте секрет и сервер, затем: меню → «Обновить данные сейчас».'
  );
}

function refreshDashboard() {
  try {
    renderAll_();
    Logger.log('refreshDashboard: данные обновлены');
  } catch (e) {
    alert_('Ошибка обновления', String(e.message || e));
    throw e;
  }
}

// ---------------------------------------------------------------------------------------
// Полный цикл: получить данные → записать значения → оформление → графики
// ---------------------------------------------------------------------------------------
function renderAll_() {
  var service = ensureServiceSheet_();
  var stamp = nowStamp_();
  try {
    var secret = getSecret_(false);
    var data = fetchAll_(secret);
    var model = buildModel_(data, stamp);

    ensureSheets_();
    removeAllProtections_();

    writeSummary_(model);
    writeFeatures_(model);
    writeHistory_(model);
    writeAchievements_(model);
    writeApps_(model);
    writeDashboard_(model);
    buildCharts_(model);

    writeService_(service, model.dateText, stamp, 'OK', null);
    SpreadsheetApp.flush();
    return model;
  } catch (e) {
    var dateText = '';
    try {
      var v = getSheet_(CFG.SHEET.summary, 1).getRange('B2').getValue();
      dateText = (v instanceof Date)
        ? Utilities.formatDate(v, 'GMT', 'yyyy-MM-dd')
        : String(v === null ? '' : v);
    } catch (ignore) {}
    try { writeService_(service, dateText, stamp, 'ОШИБКА: ' + e.message, e); } catch (ignore) {}
    noteFailureOnDashboard_(e, dateText);
    throw e;
  }
}

function fetchAll_(secret) {
  return {
    summary:      fetchCsv_(secret, 'summary', ''),
    features:     fetchCsv_(secret, 'features', ''),
    history:      fetchCsv_(secret, 'daily', '&days=' + CFG.HISTORY_DAYS),
    achievements: fetchCsv_(secret, 'achievements', ''),
    apps:         fetchCsv_(secret, 'top_apps', '')
  };
}

// ---------------------------------------------------------------------------------------
// Листы и защиты
// ---------------------------------------------------------------------------------------
function ensureSheets_() {
  getSheet_(CFG.SHEET.dashboard, 0);
  getSheet_(CFG.SHEET.summary, 1);
  getSheet_(CFG.SHEET.features, 2);
  getSheet_(CFG.SHEET.history, 3);
  getSheet_(CFG.SHEET.achievements, 4);
  getSheet_(CFG.SHEET.apps, 5);
  ensureServiceSheet_();
}

function getSheet_(name, index) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName(name);
  if (!sheet) sheet = ss.insertSheet(name);
  if (typeof index === 'number') {
    try {                              // скрытый лист нельзя активировать — это не ошибка
      ss.setActiveSheet(sheet);
      ss.moveActiveSheet(index + 1);
    } catch (ignore) {}
  }
  return sheet;
}

function ensureServiceSheet_() {
  var sheet = getSheet_(CFG.SHEET.service, 6);
  try { sheet.hideSheet(); } catch (ignore) {}
  return sheet;
}

function removeAllProtections_() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  [CFG.SHEET.dashboard, CFG.SHEET.summary, CFG.SHEET.features, CFG.SHEET.history,
   CFG.SHEET.achievements, CFG.SHEET.apps, CFG.SHEET.service
  ].forEach(function (name) {
    try {
      var sh = ss.getSheetByName(name);
      if (!sh) return;
      sh.getProtections(SpreadsheetApp.ProtectionType.SHEET)
        .forEach(function (p) { p.remove(); });
    } catch (ignore) {}
  });
}

// ---------------------------------------------------------------------------------------
// Секрет и загрузка CSV
// ---------------------------------------------------------------------------------------
function getSecret_(interactive) {
  var props = PropertiesService.getScriptProperties();
  var secret = props.getProperty(CFG.SECRET_PROPERTY);
  if (secret) return secret;

  if (interactive) {
    var ui = safeUi_();
    if (ui) {
      try {
        var resp = ui.prompt(
          'Ключ доступа к аналитике',
          'Вставьте секрет EXPORT_STATS_SECRET (выдаётся отдельно) и нажмите OK.\n' +
          'Он сохранится в свойствах скрипта и не появится ни на одном листе.',
          ui.ButtonSet.OK_CANCEL
        );
        if (resp.getSelectedButton() === ui.Button.OK) {
          secret = resp.getResponseText().trim();
          if (secret) {
            props.setProperty(CFG.SECRET_PROPERTY, secret);
            return secret;
          }
        }
      } catch (e) {
        Logger.log('prompt недоступен: ' + e);
      }
    }
  }
  throw new Error('Секрет не задан. Меню «Аналитика Good Family» → «Настроить / обновить дашборд».');
}

function fetchCsv_(secret, table, extra) {
  var url = CFG.SOURCE_URL +
            '?secret=' + encodeURIComponent(secret) +
            '&format=csv&table=' + table + (extra || '');
  var lastError = null;
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      var resp = UrlFetchApp.fetch(url, { muteHttpExceptions: true, followRedirects: true });
      var code = resp.getResponseCode();
      if (code !== 200) throw new Error('HTTP ' + code + ' (table=' + table + ')');
      var rows = Utilities.parseCsv(resp.getContentText('UTF-8'));
      return normalizeRows_(rows);
    } catch (e) {
      lastError = e;
      Utilities.sleep(1200);
    }
  }
  throw new Error('Не удалось получить «' + table + '»: ' + lastError);
}

function normalizeRows_(rows) {
  var width = 0;
  var i;
  for (i = 0; i < rows.length; i++) if (rows[i].length > width) width = rows[i].length;
  var out = [];
  for (i = 0; i < rows.length; i++) {
    if (!rows[i].length) continue;
    var row = rows[i].slice(0);
    while (row.length < width) row.push('');
    out.push(row);
  }
  while (out.length > 1) {
    var empty = true;
    for (var c = 0; c < out[out.length - 1].length; c++) {
      if (String(out[out.length - 1][c]).trim() !== '') { empty = false; break; }
    }
    if (!empty) break;
    out.pop();
  }
  return out;
}

// ---------------------------------------------------------------------------------------
// Модель: все вычисления здесь, в JS (на листах — только значения)
// ---------------------------------------------------------------------------------------
function buildModel_(data, stamp) {
  var m = { stamp: stamp };
  var summary = {};

  (data.summary || []).slice(1).forEach(function (row) {
    if (row && row[0]) summary[String(row[0])] = row[1];
  });

  function n(key) { return num_(summary[key]); }
  function s(key) { return String(summary[key] === undefined ? '' : summary[key]); }

  m.dateText = s('date_measured').substring(0, 10);
  m.activeFamilies = n('active_families_yesterday');
  m.activeMembers  = n('active_members_yesterday');
  m.totalFamilies  = n('total_families');
  m.totalMembers   = n('total_members');
  m.totalAccounts  = n('total_accounts');
  m.newFamilies    = n('new_families_yesterday');
  m.newMembers     = n('new_members_yesterday');
  m.newAccounts    = n('new_accounts_yesterday');
  m.syncs          = n('syncs_yesterday');
  m.tasksCreatedY  = n('tasks_created_yesterday');
  m.tasksDoneY     = n('tasks_done_yesterday');
  m.tasksApprovedY = n('tasks_approved_yesterday');
  m.achievementsY  = n('achievements_yesterday');
  m.gardenY        = n('garden_changes_yesterday');
  m.rewardsY       = n('rewards_requested_yesterday');

  m.features = (data.features || []).slice(1)
    .filter(function (r) { return r && r[0]; })
    .map(function (r) {
      return { name: String(r[0]), yesterday: num_(r[1]), total: num_(r[2]) };
    });

  m.featureByName = {};
  m.features.forEach(function (f) { m.featureByName[f.name] = f; });

  m.productFeatures = m.features
    .filter(function (f) { return f.name.indexOf('Новые') !== 0; })
    .sort(function (a, b) { return b.yesterday - a.yesterday; });

  m.topFeature = m.productFeatures.length ? m.productFeatures[0].name : '—';
  m.topFeatureCount = m.productFeatures.length ? m.productFeatures[0].yesterday : 0;

  m.history = (data.history || []).slice(1)
    .filter(function (r) { return r && r[0]; })
    .map(function (r) {
      return {
        date: String(r[0]).substring(0, 10),
        members: num_(r[1]),
        families: num_(r[2]),
        syncs: num_(r[3]),
        tasks: num_(r[4]),
        achievements: num_(r[5])
      };
    });

  m.apps = (data.apps || []).slice(1)
    .filter(function (r) { return r && r[0]; })
    .map(function (r) { return { app: String(r[0]), minutes: num_(r[1]) }; });
  m.topApps = m.apps.slice(0, 10);

  m.achievements = (data.achievements || []).slice(1)
    .filter(function (r) { return r && r[0]; })
    .map(function (r) { return [String(r[0]), String(r[1]), num_(r[2])]; });

  var last = m.history.length ? m.history[m.history.length - 1] : null;
  m.lastTasksDone = last ? last.tasks : 0;
  m.daysHistory = m.history.length;
  m.avgMembers = m.totalFamilies > 0 ? Math.round((m.totalMembers / m.totalFamilies) * 100) / 100 : 0;

  m.createdTotal  = featureTotal_(m, 'Хорошие дела: создано');
  m.doneTotal     = featureTotal_(m, 'Хорошие дела: выполнено ребёнком');
  m.approvedTotal = featureTotal_(m, 'Хорошие дела: подтверждено родителем');

  m.pctActiveFamilies = pct_(m.activeFamilies, m.totalFamilies);
  m.pctCreatedDone = pct_(m.doneTotal, m.createdTotal);
  m.pctDoneApproved = pct_(m.approvedTotal, m.doneTotal);

  m.featureTable = [
    ['Хорошие дела: создано', 'задание придумано родителем'],
    ['Хорошие дела: выполнено ребёнком', 'ребёнок нажал «Я сделал»'],
    ['Хорошие дела: подтверждено родителем', 'родитель принял → начислены звёзды'],
    ['Достижения: получено', 'личные/групповые достижения'],
    ['Семейный сад: изменения', 'уровень/прогресс сада'],
    ['Награды: запрошено', 'ребёнок обменял звёзды на награду']
  ];

  m.funnel = [
    ['Семей всего', m.totalFamilies, ''],
    ['Активные семьи вчера', m.activeFamilies,
      m.totalFamilies > 0 ? m.pctActiveFamilies + '% семей были активны' : ''],
    ['Участников всего', m.totalMembers, ''],
    ['Активные пользователи вчера', m.activeMembers,
      m.activeMembers <= m.totalMembers ? 'ok' : '⚠ активных больше, чем участников'],
    ['Участников на семью (в среднем)', m.avgMembers, 'в среднем на одну семью'],
    ['Хорошие дела: создано (всего)', m.createdTotal, 'все задания семьи за всё время'],
    ['Хорошие дела: выполнено (всего)', m.doneTotal,
      m.createdTotal > 0 ? m.pctCreatedDone + '% от созданных' : ''],
    ['Хорошие дела: подтверждено (всего)', m.approvedTotal,
      m.doneTotal > 0 ? m.pctDoneApproved + '% от выполненных' : ''],
    ['Новые семьи вчера', m.newFamilies, ''],
    ['Новые участники вчера', m.newMembers, ''],
    ['Новые аккаунты вчера', m.newAccounts, 'аккаунты = пользователи сервера (users)']
  ];

  m.checks = [
    ['Дней истории', m.daysHistory + ' дн.',
      'экранное время пишется с 07.11.2026 — графики накопятся'],
    ['Задания вчера: история vs summary',
      m.lastTasksDone === m.tasksDoneY ? 'ok' : '⚠',
      'история: ' + m.lastTasksDone + ' · summary: ' + m.tasksDoneY],
    ['Активные пользователи',
      m.activeMembers <= m.totalMembers ? 'ok' : '⚠',
      'активных ' + m.activeMembers + ' из ' + m.totalMembers + ' участников'],
    ['Синхронизации vs активные',
      m.syncs === m.activeMembers ? 'ok' : '⚠',
      'syncs ' + m.syncs + ' vs активных ' + m.activeMembers],
    ['Достижения', m.achievementsY === 0 ? '0' : 'ok',
      '0 — ещё никто не заработал, это не ошибка'],
    ['Семейный сад', m.gardenY === 0 ? '0' : 'ok',
      '0 — садом пока не пользуются'],
    ['Топ приложений', m.topApps.length ? 'вкл.' : 'нет данных',
      'минуты за вчера, аномалии обрезаны на сервере; см. блок «Топ приложений»']
  ];

  return m;
}

function featureTotal_(model, name) {
  var f = model.featureByName[name];
  return f ? f.total : 0;
}

function featureYesterday_(model, name) {
  var f = model.featureByName[name];
  return f ? f.yesterday : 0;
}

function num_(value) {
  if (value === null || value === undefined) return 0;
  if (typeof value === 'number') return isFinite(value) ? value : 0;
  var s = String(value).replace(/\s/g, '').replace(',', '.');
  if (s === '') return 0;
  var n = Number(s);
  return isFinite(n) ? n : 0;
}

function pct_(part, whole) {
  if (!whole) return '0';
  return String(Math.round((part / whole) * 100));
}

function nowStamp_() {
  try {
    return Utilities.formatDate(new Date(), 'Europe/Moscow', 'dd.MM.yyyy HH:mm');
  } catch (e) {
    return Utilities.formatDate(new Date(), Session.getScriptTimeZone() || 'GMT', 'dd.MM.yyyy HH:mm');
  }
}

// ---------------------------------------------------------------------------------------
// Запись листов данных — только значения
// ---------------------------------------------------------------------------------------
function writeSummary_(m) {
  var sheet = getSheet_(CFG.SHEET.summary, 1);
  sheet.clearContents();
  sheet.getRange('A1:B1').setValues([['metric', 'value']]);

  var metrics = [
    ['date_measured', m.dateText],
    ['active_families_yesterday', m.activeFamilies],
    ['active_members_yesterday', m.activeMembers],
    ['total_families', m.totalFamilies],
    ['total_members', m.totalMembers],
    ['total_accounts', m.totalAccounts],
    ['new_families_yesterday', m.newFamilies],
    ['new_members_yesterday', m.newMembers],
    ['new_accounts_yesterday', m.newAccounts],
    ['syncs_yesterday', m.syncs],
    ['tasks_created_yesterday', m.tasksCreatedY],
    ['tasks_done_yesterday', m.tasksDoneY],
    ['tasks_approved_yesterday', m.tasksApprovedY],
    ['achievements_yesterday', m.achievementsY],
    ['garden_changes_yesterday', m.gardenY],
    ['rewards_requested_yesterday', m.rewardsY]
  ];

  sheet.getRange('B2').setNumberFormat('@');   // дата — текстом, ДО записи
  sheet.getRange(2, 1, metrics.length, 2).setValues(metrics);
  sheet.getRange('B3:B17').setNumberFormat('#,##0');
  if (sheet.getRange('B2').getValue() instanceof Date) {   // страховка от автопарсинга
    sheet.getRange('B2').setNumberFormat('@').setValue(m.dateText);
  }

  styleTable_(sheet, 2, [200, 110]);
  sheet.setFrozenRows(1);
}

function writeFeatures_(m) {
  var sheet = getSheet_(CFG.SHEET.features, 2);
  sheet.clearContents();

  var rows = [['feature', 'yesterday', 'total']];
  m.features.forEach(function (f) { rows.push([f.name, f.yesterday, f.total]); });
  sheet.getRange(1, 1, rows.length, 3).setValues(rows);

  // хелпер для графика: только функции, по убыванию (значения, не формула)
  sheet.getRange('D1:E1').setValues([['Функция (по популярности)', 'Вчера']]);
  var sorted = [];
  m.productFeatures.slice(0, 7).forEach(function (f) { sorted.push([f.name, f.yesterday]); });
  while (sorted.length < 7) sorted.push(['', '']);
  sheet.getRange('D2:E8').setValues(sorted);

  styleTable_(sheet, 3, [300, 110, 110]);
  sheet.getRange('D1:E8').setFontSize(10).setVerticalAlignment('middle');
  sheet.getRange('D1:E1').setFontWeight('bold').setBackground(CFG.C.head);
  sheet.setColumnWidth(4, 300);
  sheet.setColumnWidth(5, 90);
  sheet.setFrozenRows(1);
}

function writeHistory_(m) {
  var sheet = getSheet_(CFG.SHEET.history, 3);
  sheet.clearContents();

  var rows = [['date', 'active_members', 'active_families', 'syncs', 'tasks_done', 'achievements']];
  m.history.forEach(function (h) {
    rows.push([h.date, h.members, h.families, h.syncs, h.tasks, h.achievements]);
  });
  sheet.getRange('A2:A1000').setNumberFormat('@');   // даты — текстом, ДО записи
  sheet.getRange(1, 1, rows.length, 6).setValues(rows);
  sheet.getRange('B2:F1000').setNumberFormat('#,##0');
  if (m.history.length && sheet.getRange('A2').getValue() instanceof Date) {
    for (var i = 0; i < rows.length - 1; i++) {
      sheet.getRange(2 + i, 1).setNumberFormat('@').setValue(rows[i + 1][0]);
    }
  }

  // служебные значения для блока «Качество данных» (без формул)
  sheet.getRange('G1:I1').setValues([['Дней с данными', 'Задания в последний день', 'Последняя дата']]);
  var last = m.history.length ? m.history[m.history.length - 1] : null;
  sheet.getRange('G2').setValue(m.daysHistory);
  sheet.getRange('H2').setValue(last ? last.tasks : 0);
  sheet.getRange('I2').setNumberFormat('@').setValue(last ? last.date : '');

  styleTable_(sheet, 6, [110, 130, 130, 90, 110, 120]);
  sheet.getRange('G1:I1').setFontWeight('bold').setBackground(CFG.C.head);
  sheet.getRange('G1:I100').setFontSize(10);
  try { sheet.hideColumns(7, 3); } catch (ignore) {}
  sheet.setFrozenRows(1);
}

function writeAchievements_(m) {
  var sheet = getSheet_(CFG.SHEET.achievements, 4);
  sheet.clearContents();
  var rows = [['achievement_key', 'period', 'count']];
  m.achievements.forEach(function (a) { rows.push(a); });
  sheet.getRange(1, 1, rows.length, 3).setValues(rows);
  sheet.getRange('C2:C100').setNumberFormat('#,##0');
  styleTable_(sheet, 3, [170, 110, 90]);
  sheet.setFrozenRows(1);
}

function writeApps_(m) {
  var sheet = getSheet_(CFG.SHEET.apps, 5);
  sheet.clearContents();
  var rows = [['app', 'minutes_yesterday', 'Часы (суммарно)']];
  m.apps.forEach(function (a) {
    rows.push([a.app, a.minutes, Math.round((a.minutes / 60) * 10) / 10]);
  });
  sheet.getRange(1, 1, rows.length, 3).setValues(rows);
  sheet.getRange('B2:B100').setNumberFormat('#,##0');
  sheet.getRange('C2:C100').setNumberFormat('0.0');
  styleTable_(sheet, 3, [340, 150, 130]);
  sheet.getRange('C1').setFontWeight('bold').setBackground(CFG.C.head);
  sheet.setFrozenRows(1);
}

function styleTable_(sheet, cols, widths) {
  var lastRow = Math.max(sheet.getLastRow(), 1);
  var header = sheet.getRange(1, 1, 1, cols);
  header.setFontWeight('bold')
        .setBackground(CFG.C.head)
        .setFontColor(CFG.C.sectionText)
        .setVerticalAlignment('middle');
  sheet.getRange(1, 1, lastRow, cols)
       .setFontSize(10)
       .setVerticalAlignment('middle')
       .setBorder(true, true, true, true, true, true, CFG.C.border, SpreadsheetApp.BorderStyle.SOLID);
  for (var c = 0; c < cols; c++) {
    sheet.setColumnWidth(c + 1, widths[c] || 140);
  }
}

// ---------------------------------------------------------------------------------------
// Лист «Дашборд» — значения + оформление + графики
// ---------------------------------------------------------------------------------------
function writeDashboard_(m) {
  var dash = getSheet_(CFG.SHEET.dashboard, 0);

  dash.getCharts().forEach(function (chart) { dash.removeChart(chart); });
  dash.setConditionalFormatRules([]);
  try { dash.getRange('A1:H200').breakApart(); } catch (ignore) {}
  dash.clearContents();
  try { dash.getRange('A1:H200').clearFormat(); } catch (ignore) {}
  dash.setFrozenRows(2);

  var widths = [200, 115, 115, 250, 120, 120, 120, 120];
  for (var i = 0; i < widths.length; i++) dash.setColumnWidth(i + 1, widths[i]);

  // Шапка
  dash.getRange('A1:H1').merge()
      .setValue('Good Family · продуктовая аналитика')
      .setBackground(CFG.C.dark)
      .setFontColor(CFG.C.white)
      .setFontSize(18)
      .setFontWeight('bold')
      .setVerticalAlignment('middle')
      .setHorizontalAlignment('left');
  dash.setRowHeight(1, 42);

  dash.getRange('A2:H2').merge()
      .setValue('Данные за ' + (m.dateText || '—') + ' (вчера, UTC) · обновлено: ' + m.stamp)
      .setFontSize(10)
      .setFontColor(CFG.C.muted)
      .setHorizontalAlignment('left');
  dash.setRowHeight(2, 22);

  // KPI
  section_(dash, 4, 'КЛЮЧЕВЫЕ KPI ЗА ВЧЕРА');
  kpiCard_(dash, 1, 'АКТИВНЫЕ СЕМЬИ (ВЧЕРА)', m.activeFamilies,
    'из ' + m.totalFamilies + ' семей · ' + m.pctActiveFamilies + '% активны',
    CFG.C.lightGreen, CFG.C.green, false);
  kpiCard_(dash, 3, 'АКТИВНЫЕ ПОЛЬЗОВАТЕЛИ (ВЧЕРА)', m.activeMembers,
    'всего участников: ' + m.totalMembers,
    CFG.C.lightBlue, CFG.C.blue, false);
  kpiCard_(dash, 5, 'ТОП-ФУНКЦИЯ (ВЧЕРА)', m.topFeature,
    'событий за вчера: ' + m.topFeatureCount,
    CFG.C.lightAmber, CFG.C.amber, true);
  kpiCard_(dash, 7, 'НОВЫЕ СЕМЬИ (ВЧЕРА)', m.newFamilies,
    'новых участников: ' + m.newMembers + ' · аккаунтов: ' + m.newAccounts,
    CFG.C.lightPurple, CFG.C.purple, false);

  // Функции
  section_(dash, 9, 'ХОРОШИЕ ДЕЛА, САД, ДОСТИЖЕНИЯ — ВЧЕРА И ВСЕГО');
  tableHead_(dash, 10, ['Функция', 'Вчера', 'Всего', 'Комментарий']);
  for (var r = 0; r < m.featureTable.length; r++) {
    var row = 11 + r;
    var name = m.featureTable[r][0];
    dash.getRange(row, 1).setValue(name);
    dash.getRange(row, 2).setValue(featureYesterday_(m, name)).setNumberFormat('#,##0');
    dash.getRange(row, 3).setValue(featureTotal_(m, name)).setNumberFormat('#,##0');
    dash.getRange(row, 4).setValue(m.featureTable[r][1]);
    band_(dash, row, 4, r);
  }

  // Воронка и охват
  section_(dash, 18, 'ВОРОНКА И ОХВАТ');
  tableHead_(dash, 19, ['Метрика', 'Значение', 'Комментарий']);
  for (var f = 0; f < m.funnel.length; f++) {
    var fr = 20 + f;
    dash.getRange(fr, 1).setValue(m.funnel[f][0]);
    dash.getRange(fr, 2).setValue(m.funnel[f][1])
        .setNumberFormat(f === 4 ? '0.00' : '#,##0');
    dash.getRange(fr, 3).setValue(m.funnel[f][2]);
    band_(dash, fr, 3, f);
  }

  // Качество данных
  section_(dash, 32, 'КАЧЕСТВО ДАННЫХ — ПРОЧТИТЕ ПЕРЕД ВЫВОДАМИ');
  tableHead_(dash, 33, ['Проверка', 'Статус', 'Пояснение']);
  for (var k = 0; k < m.checks.length; k++) {
    var cr = 34 + k;
    dash.getRange(cr, 1).setValue(m.checks[k][0]);
    dash.getRange(cr, 2).setValue(m.checks[k][1]);
    dash.getRange(cr, 3).setValue(m.checks[k][2]);
    band_(dash, cr, 3, k);
  }
  var rules = [
    SpreadsheetApp.newConditionalFormatRule()
      .whenTextContains('⚠')
      .setBackground(CFG.C.lightRed)
      .setFontColor(CFG.C.red)
      .setRanges([dash.getRange('B34:B40')])
      .build(),
    SpreadsheetApp.newConditionalFormatRule()
      .whenTextEqualTo('ok')
      .setFontColor(CFG.C.green)
      .setBold(true)
      .setRanges([dash.getRange('B34:B40')])
      .build()
  ];
  dash.setConditionalFormatRules(rules);

  // Топ приложений (минуты за вчера; аномалии обрезаны на сервере)
  section_(dash, 42, 'ТОП ПРИЛОЖЕНИЙ ЗА ВЧЕРА (МИНУТЫ, С ОБРЕЗКОЙ АНОМАЛИЙ)');
  tableHead_(dash, 43, ['Приложение', 'Минуты', 'Часы']);
  if (!m.topApps.length) {
    dash.getRange('A44:H44').merge()
        .setValue('Нет данных за вчера')
        .setFontSize(10).setFontColor(CFG.C.muted);
  } else {
    for (var a = 0; a < m.topApps.length; a++) {
      var ar = 44 + a;
      dash.getRange(ar, 1).setValue(m.topApps[a].app);
      dash.getRange(ar, 2).setValue(m.topApps[a].minutes).setNumberFormat('#,##0');
      dash.getRange(ar, 3)
          .setValue(Math.round((m.topApps[a].minutes / 60) * 10) / 10)
          .setNumberFormat('0.0');
      band_(dash, ar, 3, a);
    }
  }

  // Ограничения
  section_(dash, 55, 'ЧЕГО ПОКА НЕТ И ПОЧЕМУ');
  dash.getRange('A56:H56').merge()
      .setValue('Retention, DAU/WAU, когорты и воронка «семья → приглашение → первая задача» требуют серверных срезов по когортам; текущий экспорт отдаёт только суточные агрегаты. Пустые графики-заглушки не добавляем.')
      .setWrap(true).setFontSize(10).setFontColor(CFG.C.muted);
  dash.getRange('A57:H57').merge()
      .setValue('Топ приложений — минуты за вчера, экстремальные значения обрезаны на сервере. В список может попадать само приложение (com.example.family_focus) и служебные пакеты.')
      .setWrap(true).setFontSize(10).setFontColor(CFG.C.muted);

  section_(dash, 59, 'ГРАФИКИ');
  protectSheet_(dash, 'Лист собирается скриптом. Ручные правки перезапишутся при обновлении.');
  dash.activate();
}

function section_(dash, row, text) {
  dash.getRange(row, 1, 1, 8).merge()
      .setValue(text)
      .setBackground(CFG.C.section)
      .setFontColor(CFG.C.sectionText)
      .setFontWeight('bold')
      .setFontSize(11)
      .setVerticalAlignment('middle');
  dash.setRowHeight(row, 27);
}

function kpiCard_(dash, col, label, value, sub, fill, valueColor, isText) {
  var labelRange = dash.getRange(5, col, 1, 2);
  var valueRange = dash.getRange(6, col, 1, 2);
  var subRange   = dash.getRange(7, col, 1, 2);
  var block      = dash.getRange(5, col, 3, 2);

  labelRange.merge().setValue(label)
    .setFontSize(9).setFontColor(CFG.C.muted).setVerticalAlignment('bottom')
    .setHorizontalAlignment('left');
  valueRange.merge().setValue(value)
    .setFontSize(isText ? 13 : 26)
    .setFontWeight('bold').setFontColor(valueColor)
    .setVerticalAlignment('middle').setHorizontalAlignment('left')
    .setWrap(true);
  if (!isText) valueRange.setNumberFormat('#,##0');
  subRange.merge().setValue(sub)
    .setFontSize(9).setFontColor(CFG.C.muted)
    .setVerticalAlignment('top').setHorizontalAlignment('left').setWrap(true);

  block.setBackground(fill)
       .setBorder(true, true, true, true, true, true, CFG.C.border, SpreadsheetApp.BorderStyle.SOLID);
  dash.setRowHeight(5, 18);
  dash.setRowHeight(6, 38);
  dash.setRowHeight(7, 20);
}

function tableHead_(dash, row, titles) {
  for (var c = 0; c < titles.length; c++) dash.getRange(row, c + 1).setValue(titles[c]);
  dash.getRange(row, 1, 1, titles.length)
      .setBackground(CFG.C.head)
      .setFontWeight('bold')
      .setFontSize(10)
      .setVerticalAlignment('middle');
  dash.setRowHeight(row, 24);
}

function band_(dash, row, cols, index) {
  if (index % 2 === 1) dash.getRange(row, 1, 1, cols).setBackground(CFG.C.band);
  dash.getRange(row, 1, 1, cols).setFontSize(10).setVerticalAlignment('middle');
  dash.setRowHeight(row, 21);
}

// ---------------------------------------------------------------------------------------
// Графики (все диапазоны — на значениях, без формул)
// ---------------------------------------------------------------------------------------
function buildCharts_(m) {
  var dash = getSheet_(CFG.SHEET.dashboard, 0);
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var chartErrors = [];

  // 1. Динамика: последние 30 дней
  if (m.history.length > 0) {
    try {
      var hist = ss.getSheetByName(CFG.SHEET.history);
      var lastRow = hist.getLastRow();
      var start = Math.max(2, lastRow - 29);
      dash.insertChart(dash.newChart()
        .setChartType(Charts.ChartType.LINE)
        .addRange(hist.getRange(start, 1, lastRow - start + 1, 3))
        .setNumHeaders(0)
        .setPosition(60, 1, 0, 0)
        .setOption('title', 'Активность: пользователи и семьи (до 30 дней)')
        .setOption('width', 470).setOption('height', 290)
        .setOption('legend', { position: 'bottom' })
        .setOption('colors', [CFG.C.blue, CFG.C.green])
        .setOption('pointSize', 6)
        .setOption('vAxis', { minValue: 0, title: 'человек / семей' })
        .setOption('hAxis', { title: 'дата' })
        .build());
    } catch (e) { chartErrors.push('динамика: ' + e.message); }
  }

  // 2. Функции за вчера (по убыванию)
  try {
    var feat = ss.getSheetByName(CFG.SHEET.features);
    dash.insertChart(dash.newChart()
      .setChartType(Charts.ChartType.BAR)
      .addRange(feat.getRange('D1:E8'))
      .setNumHeaders(1)
      .setPosition(60, 5, 0, 0)
      .setOption('title', 'Функции за вчера (по убыванию)')
      .setOption('width', 470).setOption('height', 290)
      .setOption('legend', { position: 'none' })
      .setOption('colors', [CFG.C.green])
      .build());
  } catch (e) { chartErrors.push('функции: ' + e.message); }

  // 3. Воронка хороших дел
  try {
    dash.insertChart(dash.newChart()
      .setChartType(Charts.ChartType.COLUMN)
      .addRange(dash.getRange('A25:B27'))
      .setNumHeaders(0)
      .setPosition(75, 1, 0, 0)
      .setOption('title', 'Хорошие дела: создано → выполнено → подтверждено (всего)')
      .setOption('width', 470).setOption('height', 280)
      .setOption('legend', { position: 'none' })
      .setOption('colors', [CFG.C.green])
      .build());
  } catch (e) { chartErrors.push('воронка: ' + e.message); }

  // 4. Привлечение за вчера
  try {
    dash.insertChart(dash.newChart()
      .setChartType(Charts.ChartType.COLUMN)
      .addRange(dash.getRange('A28:B30'))
      .setNumHeaders(0)
      .setPosition(75, 5, 0, 0)
      .setOption('title', 'Привлечение за вчера')
      .setOption('width', 470).setOption('height', 280)
      .setOption('legend', { position: 'none' })
      .setOption('colors', [CFG.C.blue])
      .build());
  } catch (e) { chartErrors.push('привлечение: ' + e.message); }

  // Графики не должны валить весь дашборд: если что-то не так — пишем в диагностику.
  if (chartErrors.length) {
    try {
      var service = ss.getSheetByName(CFG.SHEET.service);
      if (service) service.getRange('F2').setValue('ГРАФИКИ: ' + chartErrors.join(' | '));
    } catch (ignore) {}
  }
}

// ---------------------------------------------------------------------------------------
// Служебный лист, защита, триггер
// ---------------------------------------------------------------------------------------
function writeService_(service, dateText, stamp, status, err) {
  service.getRange('A1').setValue('СЛУЖЕБНЫЙ ЛИСТ — НЕ УДАЛЯТЬ').setFontWeight('bold');
  service.getRange('A2').setValue('Время обновления, дата данных, статус. Секрет хранится в свойствах скрипта.');
  service.getRange('A3').setValue('Последнее обновление (МСК)');
  service.getRange('B3').setNumberFormat('@').setValue(stamp);
  service.getRange('A4').setValue('Дата данных');
  service.getRange('B4').setNumberFormat('@').setValue(dateText || '');
  service.getRange('A5').setValue('Статус');
  service.getRange('B5').setValue(status);
  service.getRange('A6').setValue('Источник');
  service.getRange('B6').setValue(CFG.SOURCE_URL);
  service.getRange('F1').setValue('Диагностика');
  service.getRange('F2').setValue(err ? (stamp + ' — ' + err.message) : '');
  try { service.hideSheet(); } catch (ignore) {}
  protectSheet_(service, 'Служебный лист: не удалять.');
}

function noteFailureOnDashboard_(err, dateText) {
  try {
    var dash = getSheet_(CFG.SHEET.dashboard, 0);
    dash.getRange('A2').setValue(
      'Данные за ' + (dateText || '—') + ' · ОШИБКА обновления: ' + err.message
    );
  } catch (ignore) {}
}

function protectSheet_(sheet, description) {
  try {
    sheet.getProtections(SpreadsheetApp.ProtectionType.SHEET).forEach(function (p) { p.remove(); });
    sheet.protect().setDescription(description).setWarningOnly(true);
  } catch (ignore) {}
}

function installTrigger(silent) {
  ScriptApp.getProjectTriggers().forEach(function (t) {
    if (t.getHandlerFunction() === 'refreshDashboard') ScriptApp.deleteTrigger(t);
  });
  ScriptApp.newTrigger('refreshDashboard').timeBased().everyHours(1).create();
  if (!silent) {
    alert_('Готово', 'Данные будут обновляться каждый час.');
  }
}
