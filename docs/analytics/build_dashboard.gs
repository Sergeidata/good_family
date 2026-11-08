/*******************************************************************************************
 * GOOD FAMILY — ДАШБОРД АНАЛИТИКИ В GOOGLE SHEETS
 * -----------------------------------------------------------------------------------------
 * Что это: один скрипт, который сам собирает дашборд на листах существующей таблицы.
 * Источник данных: http://89.108.66.36/export_stats (CSV). БД напрямую не трогаем.
 *
 * КАК ЗАПУСТИТЬ (владельцу таблицы, без терминала и git):
 *   1. В таблице: Расширения → Apps Script.
 *   2. Удалить весь код в файле Code.gs и вставить этот код целиком. Сохранить (💾).
 *   3. Вернуться в таблицу, обновить страницу (F5).
 *   4. В меню сверху: «Аналитика Good Family» → «Настроить / обновить дашборд».
 *   5. Вставить секрет в диалоговом окне (секрет выдаётся отдельно) → OK.
 *   6. Подождать 20–60 секунд. Готово: данные обновляются каждый час автоматически.
 *
 * Секрет НЕ хранится на листах: он лежит в свойствах скрипта (PropertiesService).
 * Ничего не удаляйте и не переименовывайте листы: «Дашборд», «Сырые данные», «Функции»,
 * «История», «Достижения», «Приложения», «_Служебный». Повторный запуск «Настроить дашборд»
 * безопасен — он пересобирает листы, но не трогает посторонние листы таблицы.
 *******************************************************************************************/

var CFG = {
  SOURCE_URL: 'http://89.108.66.36/export_stats',
  SECRET_PROPERTY: 'EXPORT_STATS_SECRET',
  HISTORY_DAYS: 90,
  SHEET: {
    dashboard:   'Дашборд',
    summary:     'Сырые данные',
    features:    'Функции',
    history:     'История',
    achievements:'Достижения',
    apps:        'Приложения',
    service:     '_Служебный'
  },
  C: {
    dark:      '#1B5E20',
    green:     '#2E7D32',
    lightGreen:'#E8F5E9',
    blue:      '#1565C0',
    lightBlue: '#E3F2FD',
    amber:     '#EF6C00',
    lightAmber:'#FFF8E1',
    purple:    '#6A1B9A',
    lightPurple:'#F3E5F5',
    section:   '#ECEFF1',
    sectionText:'#263238',
    head:      '#CFD8DC',
    border:    '#CFD8DC',
    text:      '#212121',
    muted:     '#546E7A',
    red:       '#C62828',
    lightRed:  '#FFEBEE',
    white:     '#FFFFFF',
    band:      '#F7F9FA'
  }
};

// ---------------------------------------------------------------------------------------
// Меню в таблице
// ---------------------------------------------------------------------------------------
function onOpen() {
  SpreadsheetApp.getUi()
    .createMenu('Аналитика Good Family')
    .addItem('Настроить / обновить дашборд', 'setupDashboard')
    .addItem('Обновить данные сейчас', 'refreshDashboard')
    .addItem('Включить ежечасное обновление', 'installTrigger')
    .addItem('Как это работает (инструкция)', 'showInstructions')
    .addToUi();
}

function showInstructions() {
  var ui = SpreadsheetApp.getUi();
  ui.alert(
    'Как это работает',
    [
      '1. Данные приходят с сервера аналитики (за вчера, UTC).',
      '2. Скрипт обновляет листы «Сырые данные», «Функции», «История», «Достижения», «Приложения» каждый час.',
      '3. «Дашборд» пересчитывается сам — руками ничего менять не нужно.',
      '4. Если цифры не обновились: меню → «Обновить данные сейчас».',
      '5. Секрет хранится в свойствах скрипта и не виден на листах.',
      '',
      'Важно: не удаляйте и не переименовывайте листы — формулы дашборда ссылаются на них.'
    ].join('\n'),
    ui.ButtonSet.OK
  );
}

// ---------------------------------------------------------------------------------------
// Настройка «в один клик»
// ---------------------------------------------------------------------------------------
function setupDashboard() {
  var ui = SpreadsheetApp.getUi();
  try {
    ensureSheets_();
    getSecret_(true);              // при первом запуске спросит секрет и сохранит его
    var warn = '';
    try {
      refreshDashboard();          // загружаем данные, пока строим оформление
    } catch (e) {
      warn = e.message;
    }
    buildDashboard_();
    installTrigger(true);
    ui.alert(
      'Готово',
      'Дашборд собран. Данные обновляются каждый час автоматически.' +
      (warn ? '\n\n⚠ Последняя загрузка данных не удалась:\n' + warn +
              '\n\nПроверьте секрет: меню → «Настроить / обновить дашборд» ещё раз.' : ''),
      ui.ButtonSet.OK
    );
  } catch (e) {
    ui.alert('Ошибка', 'Не получилось собрать дашборд:\n\n' + e.message, ui.ButtonSet.OK);
  }
}

// ---------------------------------------------------------------------------------------
// Обновление данных (вызывается триггером каждый час)
// ---------------------------------------------------------------------------------------
function refreshDashboard() {
  var service = ensureServiceSheet_();
  try {
    var secret = getSecret_(false);
    var data = {
      summary:      fetchCsv_(secret, 'summary', ''),
      features:     fetchCsv_(secret, 'features', ''),
      history:      fetchCsv_(secret, 'daily', '&days=' + CFG.HISTORY_DAYS),
      achievements: fetchCsv_(secret, 'achievements', ''),
      apps:         fetchCsv_(secret, 'top_apps', '')
    };

    writeTable_(getSheet_(CFG.SHEET.summary, 1), data.summary, [1], [170, 100]);
    writeTable_(getSheet_(CFG.SHEET.features, 2), data.features, [1, 2], [300, 110, 110]);
    writeTable_(getSheet_(CFG.SHEET.history, 3), data.history, [1, 2, 3, 4, 5], [110, 130, 130, 90, 110, 120]);
    writeTable_(getSheet_(CFG.SHEET.achievements, 4), data.achievements, [2], [170, 110, 90]);
    writeTable_(getSheet_(CFG.SHEET.apps, 5), data.apps, [1], [340, 150]);

    addHelperFormulas_();
    writeServiceStatus_(service, 'OK', null);
    SpreadsheetApp.flush();
  } catch (e) {
    try { writeServiceStatus_(service, 'ОШИБКА: ' + e.message, e); } catch (ignore) {}
    throw e;
  }
}

// ---------------------------------------------------------------------------------------
// Листы
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
    try {                         // скрытые листы нельзя активировать — это не ошибка
      ss.setActiveSheet(sheet);
      ss.moveActiveSheet(index + 1);
    } catch (ignore) {}
  }
  return sheet;
}

function ensureServiceSheet_() {
  var sheet = getSheet_(CFG.SHEET.service, 6);
  if (sheet.getLastRow() === 0) {
    sheet.getRange('A1').setValue('СЛУЖЕБНЫЙ ЛИСТ — НЕ УДАЛЯТЬ').setFontWeight('bold');
    sheet.getRange('A2').setValue('Здесь: время обновления, дата данных и (опционально) URL для ручного режима IMPORTDATA.');
    sheet.getRange('A3').setValue('Последнее обновление (МСК)');
    sheet.getRange('A4').setValue('Дата данных');
    sheet.getRange('A4').setFormula('=IFERROR(VLOOKUP("date_measured",\'Сырые данные\'!A:B,2,FALSE),"нет данных")');
    sheet.getRange('A5').setValue('Статус');
    sheet.getRange('A6').setValue('Источник');
    sheet.getRange('B6').setValue(CFG.SOURCE_URL);
    sheet.getRange('F1').setValue('Диагностика');
    try { sheet.hideSheet(); } catch (ignore) {}
  }
  return sheet;
}

// ---------------------------------------------------------------------------------------
// Секрет и загрузка CSV
// ---------------------------------------------------------------------------------------
function getSecret_(interactive) {
  var props = PropertiesService.getScriptProperties();
  var secret = props.getProperty(CFG.SECRET_PROPERTY);
  if (secret) return secret;

  if (interactive) {
    var ui = SpreadsheetApp.getUi();
    var resp = ui.prompt(
      'Ключ доступа к аналитике',
      'Вставьте секрет EXPORT_STATS_SECRET (выдаётся отдельно) и нажмите OK.\n' +
      'Он сохранится в свойствах скрипта и не появится на листах.',
      ui.ButtonSet.OK_CANCEL
    );
    if (resp.getSelectedButton() === ui.Button.OK) {
      secret = resp.getResponseText().trim();
      if (secret) {
        props.setProperty(CFG.SECRET_PROPERTY, secret);
        return secret;
      }
    }
  }
  throw new Error('Секрет не задан. Откройте меню «Аналитика Good Family» → «Настроить / обновить дашборд» и введите ключ.');
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
// Запись таблиц
// ---------------------------------------------------------------------------------------
function writeTable_(sheet, rows, numericCols, widths) {
  sheet.clearContents();
  if (!rows || !rows.length) return;

  var width = rows[0].length;
  var values = convertNumeric_(rows, numericCols || []);
  var range = sheet.getRange(1, 1, values.length, width);
  range.setValues(values);
  range.setFontSize(10).setVerticalAlignment('middle');

  var header = sheet.getRange(1, 1, 1, width);
  header.setFontWeight('bold')
        .setBackground(CFG.C.head)
        .setFontColor(CFG.C.sectionText)
        .setVerticalAlignment('middle');

  sheet.setFrozenRows(1);
  sheet.getRange(1, 1, values.length, width)
       .setBorder(true, true, true, true, true, true, CFG.C.border, SpreadsheetApp.BorderStyle.SOLID);

  for (var c = 0; c < width; c++) {
    sheet.setColumnWidth(c + 1, (widths && widths[c]) ? widths[c] : 140);
  }
}

function convertNumeric_(rows, numericCols) {
  var out = [];
  for (var r = 0; r < rows.length; r++) {
    var row = rows[r].slice(0);
    if (r > 0) { // заголовок не трогаем
      for (var k = 0; k < numericCols.length; k++) {
        var c = numericCols[k];
        var v = String(row[c] === undefined ? '' : row[c]).trim();
        if (v !== '' && /^-?\d+(\.\d+)?$/.test(v)) row[c] = Number(v);
      }
    }
    out.push(row);
  }
  return out;
}

// ---------------------------------------------------------------------------------------
// Служебные колонки на листах данных (нужны формулам дашборда)
// ---------------------------------------------------------------------------------------
function addHelperFormulas_() {
  // «Функции»: D:E — только продуктовые функции (без «Новые ...»), по убыванию за вчера.
  var f = getSheet_(CFG.SHEET.features, 2);
  f.getRange('D1:E1').setValues([['Функция (по популярности)', 'Вчера']])
      .setFontWeight('bold')
      .setBackground(CFG.C.head)
      .setFontColor(CFG.C.sectionText);
  f.getRange('D2').setFormula(
    '=IFERROR(SORT(FILTER($A$2:$B$100,$A$2:$A$100<>"",LEFT($A$2:$A$100,5)<>"Новые"),2,FALSE),"")'
  );
  f.setColumnWidth(4, 300);
  f.setColumnWidth(5, 90);

  // «История»: G:I — служебные значения для проверок (колонки скрыты).
  var h = getSheet_(CFG.SHEET.history, 3);
  h.getRange('G1').setValue('Дней с данными');
  h.getRange('H1').setValue('Задания в последний день');
  h.getRange('I1').setValue('Последняя дата');
  h.getRange('G2').setFormula('=COUNTA($A$2:$A$1000)');
  h.getRange('H2').setFormula('=IFERROR(INDEX($E$2:$E$1000,COUNTA($A$2:$A$1000)),"")');
  h.getRange('I2').setFormula('=IFERROR(INDEX($A$2:$A$1000,COUNTA($A$2:$A$1000)),"")');
  h.getRange('G1:I1').setFontWeight('bold').setBackground(CFG.C.head);
  h.hideColumns(7, 3);

  // «Приложения»: C — часы для читаемости (данные недостоверны до фикса клиента).
  var a = getSheet_(CFG.SHEET.apps, 5);
  a.getRange('C1').setValue('Часы (суммарно)').setFontWeight('bold').setBackground(CFG.C.head);
  a.getRange('C2').setFormula('=ARRAYFORMULA(IF($B$2:$B$100="","",ROUND($B$2:$B$100/60,1)))');
  a.setColumnWidth(3, 130);
}

function writeServiceStatus_(service, status, err) {
  var tz = 'Europe/Moscow';
  var stamp = '';
  try {
    stamp = Utilities.formatDate(new Date(), tz, 'dd.MM.yyyy HH:mm');
  } catch (e) {
    stamp = Utilities.formatDate(new Date(), Session.getScriptTimeZone() || 'GMT', 'dd.MM.yyyy HH:mm');
  }
  service.getRange('B3').setValue(stamp);
  service.getRange('B5').setValue(status);
  service.getRange('F2').setValue(err ? (stamp + ' — ' + err.message) : '');
}

// ---------------------------------------------------------------------------------------
// Построение листа «Дашборд»
// ---------------------------------------------------------------------------------------
function buildDashboard_() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var dash = getSheet_(CFG.SHEET.dashboard, 0);

  dash.getCharts().forEach(function (chart) { dash.removeChart(chart); });
  dash.setConditionalFormatRules([]);
  dash.getRange('A1:H200').breakApart();
  dash.clearContents();
  dash.getRange('A1:H200').clearFormat();
  dash.setFrozenRows(2);

  var widths = [200, 115, 115, 250, 120, 120, 120, 120];
  for (var i = 0; i < widths.length; i++) dash.setColumnWidth(i + 1, widths[i]);

  // --- Заголовок ---
  setTitle_(dash);

  // --- Блок A: 4 KPI-карточки ---
  section_(dash, 4, 'КЛЮЧЕВЫЕ KPI ЗА ВЧЕРА');
  kpiCard_(dash, 1, 'АКТИВНЫЕ СЕМЬИ (ВЧЕРА)',
    '=IFERROR(VLOOKUP("active_families_yesterday",\'Сырые данные\'!$A:$B,2,FALSE),"нет данных")',
    '=IFERROR("из "&VLOOKUP("total_families",\'Сырые данные\'!$A:$B,2,FALSE)&" семей · "&TEXT(VLOOKUP("active_families_yesterday",\'Сырые данные\'!$A:$B,2,FALSE)/VLOOKUP("total_families",\'Сырые данные\'!$A:$B,2,FALSE),"0%")&" активны","")',
    CFG.C.lightGreen, CFG.C.green, false);
  kpiCard_(dash, 3, 'АКТИВНЫЕ ПОЛЬЗОВАТЕЛИ (ВЧЕРА)',
    '=IFERROR(VLOOKUP("active_members_yesterday",\'Сырые данные\'!$A:$B,2,FALSE),"нет данных")',
    '=IFERROR("всего участников: "&VLOOKUP("total_members",\'Сырые данные\'!$A:$B,2,FALSE),"")',
    CFG.C.lightBlue, CFG.C.blue, false);
  kpiCard_(dash, 5, 'ТОП-ФУНКЦИЯ (ВЧЕРА)',
    '=IFERROR(INDEX(\'Функции\'!$D$2:$D$8,1),"нет данных")',
    '=IFERROR("событий за вчера: "&INDEX(\'Функции\'!$E$2:$E$8,1),"")',
    CFG.C.lightAmber, CFG.C.amber, true);
  kpiCard_(dash, 7, 'НОВЫЕ СЕМЬИ (ВЧЕРА)',
    '=IFERROR(VLOOKUP("new_families_yesterday",\'Сырые данные\'!$A:$B,2,FALSE),"нет данных")',
    '=IFERROR("новых участников: "&VLOOKUP("new_members_yesterday",\'Сырые данные\'!$A:$B,2,FALSE)&" · аккаунтов: "&VLOOKUP("new_accounts_yesterday",\'Сырые данные\'!$A:$B,2,FALSE),"")',
    CFG.C.lightPurple, CFG.C.purple, false);

  // --- Блок B: функции (вчера/всего) ---
  section_(dash, 9, 'ХОРОШИЕ ДЕЛА, САД, ДОСТИЖЕНИЯ — ВЧЕРА И ВСЕГО');
  tableHead_(dash, 10, ['Функция', 'Вчера', 'Всего', 'Комментарий']);
  var featureRows = [
    ['Хорошие дела: создано', 'задание придумано родителем'],
    ['Хорошие дела: выполнено ребёнком', 'ребёнок нажал «Я сделал»'],
    ['Хорошие дела: подтверждено родителем', 'родитель принял → начислены звёзды'],
    ['Достижения: получено', 'личные/групповые достижения'],
    ['Семейный сад: изменения', 'уровень/прогресс сада'],
    ['Награды: запрошено', 'ребёнок обменял звёзды на награду']
  ];
  for (var r = 0; r < featureRows.length; r++) {
    var row = 11 + r;
    dash.getRange(row, 1).setValue(featureRows[r][0]);
    dash.getRange(row, 2).setFormula('=IFERROR(VLOOKUP($A' + row + ',\'Функции\'!$A:$C,2,FALSE),"")');
    dash.getRange(row, 3).setFormula('=IFERROR(VLOOKUP($A' + row + ',\'Функции\'!$A:$C,3,FALSE),"")');
    dash.getRange(row, 4).setValue(featureRows[r][1]);
    band_(dash, row, 4, r);
  }
  formatNumberRange_(dash, 'B11:C16', '#,##0');

  // --- Блок C: воронка и охват ---
  section_(dash, 18, 'ВОРОНКА И ОХВАТ');
  tableHead_(dash, 19, ['Метрика', 'Значение', 'Комментарий']);
  var funnel = [
    ['Семей всего', '=IFERROR(VLOOKUP("total_families",\'Сырые данные\'!$A:$B,2,FALSE),"нет данных")', ''],
    ['Активные семьи вчера', '=IFERROR(VLOOKUP("active_families_yesterday",\'Сырые данные\'!$A:$B,2,FALSE),"нет данных")', '=IFERROR(TEXT(B21/B20,"0%")&" семей были активны","")'],
    ['Участников всего', '=IFERROR(VLOOKUP("total_members",\'Сырые данные\'!$A:$B,2,FALSE),"нет данных")', ''],
    ['Активные пользователи вчера', '=IFERROR(VLOOKUP("active_members_yesterday",\'Сырые данные\'!$A:$B,2,FALSE),"нет данных")', '=IFERROR(IF(B23>B22,"⚠ активных больше, чем участников","ok"),"")'],
    ['Участников на семью (в среднем)', '=IFERROR(ROUND(B22/B20,2),"")', 'в среднем на одну семью'],
    ['Хорошие дела: создано (всего)', '=IFERROR(C11,"")', 'все задания семьи за всё время'],
    ['Хорошие дела: выполнено (всего)', '=IFERROR(C12,"")', '=IFERROR(TEXT(B26/B25,"0%")&" от созданных","")'],
    ['Хорошие дела: подтверждено (всего)', '=IFERROR(C13,"")', '=IFERROR(TEXT(B27/B26,"0%")&" от выполненных","")'],
    ['Новые семьи вчера', '=IFERROR(VLOOKUP("new_families_yesterday",\'Сырые данные\'!$A:$B,2,FALSE),"нет данных")', ''],
    ['Новые участники вчера', '=IFERROR(VLOOKUP("new_members_yesterday",\'Сырые данные\'!$A:$B,2,FALSE),"нет данных")', ''],
    ['Новые аккаунты вчера', '=IFERROR(VLOOKUP("new_accounts_yesterday",\'Сырые данные\'!$A:$B,2,FALSE),"нет данных")', 'аккаунты = пользователи сервера (users)']
  ];
  for (var j = 0; j < funnel.length; j++) {
    var fr = 20 + j;
    dash.getRange(fr, 1).setValue(funnel[j][0]);
    dash.getRange(fr, 2).setFormula(funnel[j][1]);
    setCell_(dash.getRange(fr, 3), funnel[j][2]);
    band_(dash, fr, 3, j);
  }
  formatNumberRange_(dash, 'B20:B25', '#,##0');
  dash.getRange('B24').setNumberFormat('0.00');
  formatNumberRange_(dash, 'B25:B30', '#,##0');

  // --- Блок D: качество данных ---
  section_(dash, 32, 'КАЧЕСТВО ДАННЫХ — ПРОЧТИТЕ ПЕРЕД ВЫВОДАМИ');
  tableHead_(dash, 33, ['Проверка', 'Статус', 'Пояснение']);
  var checks = [
    ['Дней истории', '=IFERROR(\'История\'!$G$2&" дн.","")', 'экранное время пишется с 07.11.2026 — графики накопятся'],
    ['Задания вчера: история vs summary',
      '=IFERROR(IF(VLOOKUP("tasks_done_yesterday",\'Сырые данные\'!$A:$B,2,FALSE)=\'История\'!$H$2,"ok","⚠"),"нет данных")',
      '=IFERROR("история: "&\'История\'!$H$2&" · summary: "&VLOOKUP("tasks_done_yesterday",\'Сырые данные\'!$A:$B,2,FALSE),"")'],
    ['Активные пользователи',
      '=IFERROR(IF(B23<=B22,"ok","⚠"),"")',
      '=IFERROR("активных "&B23&" из "&B22&" участников","")'],
    ['Синхронизации vs активные',
      '=IFERROR(IF(VLOOKUP("syncs_yesterday",\'Сырые данные\'!$A:$B,2,FALSE)=B23,"ok","⚠"),"")',
      '=IFERROR("syncs "&VLOOKUP("syncs_yesterday",\'Сырые данные\'!$A:$B,2,FALSE)&" vs активных "&B23&" — считаются строки без member_id","")'],
    ['Достижения',
      '=IFERROR(IF(VLOOKUP("achievements_yesterday",\'Сырые данные\'!$A:$B,2,FALSE)=0,"0","ok"),"")',
      '0 — ещё никто не заработал, это не ошибка'],
    ['Семейный сад',
      '=IFERROR(IF(VLOOKUP("garden_changes_yesterday",\'Сырые данные\'!$A:$B,2,FALSE)=0,"0","ok"),"")',
      '0 — садом пока не пользуются'],
    ['Топ приложений', 'скрыт',
      'минуты накапливаются клиентом и недостоверны; не выводим на дашборд до фикса приложения']
  ];
  for (var k = 0; k < checks.length; k++) {
    var cr = 34 + k;
    dash.getRange(cr, 1).setValue(checks[k][0]);
    dash.getRange(cr, 2).setFormula(checks[k][1]);
    setCell_(dash.getRange(cr, 3), checks[k][2]);
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

  // --- Блок E: чего нет ---
  section_(dash, 42, 'ЧЕГО ПОКА НЕТ И ПОЧЕМУ');
  dash.getRange('A43:H43').merge()
      .setValue('Retention, DAU/WAU, когорты и воронка «семья → приглашение → первая задача» требуют серверных срезов по когортам; текущий экспорт отдаёт только агрегаты. Пустые графики-заглушки не добавляем.')
      .setWrap(true).setFontSize(10).setFontColor(CFG.C.muted);
  dash.getRange('A44:H44').merge()
      .setValue('Топ приложений лежит на листе «Приложения» с предупреждением: значения минут накопленные (до 160 ч/сутки у одного устройства) — до фикса клиента не используем в выводах.')
      .setWrap(true).setFontSize(10).setFontColor(CFG.C.muted);

  // --- Графики ---
  section_(dash, 46, 'ГРАФИКИ');
  buildCharts_(dash);

  // Защита и скрытие
  hideRawSheets_();
  protectSheet_(dash, 'Лист собирается скриптом. Менять вручную не нужно: правки перезапишутся.');
  protectSheet_(getSheet_(CFG.SHEET.service, 6), 'Служебный лист: не удалять.');

  dash.activate();
}

function setTitle_(dash) {
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
      .setFormula('="Данные за "&_Служебный!B4&" (вчера, UTC) · обновлено: "&_Служебный!B3&IF(_Служебный!B5="OK",""," · ⚠ "&_Служебный!B5)')
      .setFontSize(10)
      .setFontColor(CFG.C.muted)
      .setHorizontalAlignment('left');
  dash.setRowHeight(2, 22);
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

function kpiCard_(dash, col, label, valueFormula, subFormula, fill, valueColor, valueIsText) {
  var labelRange = dash.getRange(5, col, 1, 2);
  var valueRange = dash.getRange(6, col, 1, 2);
  var subRange   = dash.getRange(7, col, 1, 2);
  var block      = dash.getRange(5, col, 3, 2);

  labelRange.merge().setValue(label)
    .setFontSize(9).setFontColor(CFG.C.muted).setVerticalAlignment('bottom')
    .setHorizontalAlignment('left');
  valueRange.merge().setFormula(valueFormula)
    .setFontSize(valueIsText ? 13 : 26)
    .setFontWeight('bold').setFontColor(valueColor)
    .setVerticalAlignment('middle').setHorizontalAlignment('left')
    .setWrap(true);
  subRange.merge().setFormula(subFormula)
    .setFontSize(9).setFontColor(CFG.C.muted)
    .setVerticalAlignment('top').setHorizontalAlignment('left').setWrap(true);

  block.setBackground(fill)
       .setBorder(true, true, true, true, true, true, CFG.C.border, SpreadsheetApp.BorderStyle.SOLID);
  if (!valueIsText) valueRange.setNumberFormat('#,##0');
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

/** Пишет текст: если начинается с «=», то как формулу, иначе как значение. */
function setCell_(range, text) {
  var s = String(text === undefined || text === null ? '' : text);
  if (s.charAt(0) === '=') range.setFormula(s);
  else range.setValue(s);
}

function band_(dash, row, cols, index) {
  if (index % 2 === 1) {
    dash.getRange(row, 1, 1, cols).setBackground(CFG.C.band);
  }
  dash.getRange(row, 1, 1, cols).setFontSize(10).setVerticalAlignment('middle');
  dash.setRowHeight(row, 21);
}

function formatNumberRange_(dash, a1, format) {
  dash.getRange(a1).setNumberFormat(format);
}

function buildCharts_(dash) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();

  // 1. Динамика активности (линия, последние 30 дней). Данные накопятся со временем.
  var hist = ss.getSheetByName(CFG.SHEET.history);
  if (hist && hist.getLastRow() >= 2) {
    var last = hist.getLastRow();
    var start = Math.max(2, last - 29);
    var line = dash.newChart()
      .setChartType(Charts.ChartType.LINE)
      .addRange(hist.getRange(start, 1, last - start + 1, 3))
      .setNumHeaders(0)
      .setPosition(47, 1, 0, 0)
      .setOption('title', 'Активность: пользователи и семьи (до 30 дней)')
      .setOption('width', 470).setOption('height', 290)
      .setOption('legend', { position: 'bottom' })
      .setOption('colors', [CFG.C.blue, CFG.C.green])
      .setOption('pointSize', 6)
      .setOption('vAxis', { minValue: 0, title: 'человек / семей' })
      .setOption('hAxis', { title: 'дата' })
      .build();
    dash.insertChart(line);
  }

  // 2. Функции за вчера (горизонтальные столбцы, по убыванию).
  var feat = ss.getSheetByName(CFG.SHEET.features);
  if (feat) {
    var fun = dash.newChart()
      .setChartType(Charts.ChartType.BAR)
      .addRange(feat.getRange('D1:E8'))
      .setNumHeaders(1)
      .setPosition(47, 5, 0, 0)
      .setOption('title', 'Функции за вчера (по убыванию)')
      .setOption('width', 470).setOption('height', 290)
      .setOption('legend', { position: 'none' })
      .setOption('colors', [CFG.C.green])
      .build();
    dash.insertChart(fun);
  }

  // 3. Воронка хороших дел (всего).
  var funnel = dash.newChart()
    .setChartType(Charts.ChartType.COLUMN)
    .addRange(dash.getRange('A25:B27'))
    .setNumHeaders(0)
    .setPosition(62, 1, 0, 0)
    .setOption('title', 'Хорошие дела: создано → выполнено → подтверждено (всего)')
    .setOption('width', 470).setOption('height', 280)
    .setOption('legend', { position: 'none' })
    .setOption('colors', [CFG.C.green])
    .build();
  dash.insertChart(funnel);

  // 4. Привлечение за вчера.
  var acq = dash.newChart()
    .setChartType(Charts.ChartType.COLUMN)
    .addRange(dash.getRange('A28:B30'))
    .setNumHeaders(0)
    .setPosition(62, 5, 0, 0)
    .setOption('title', 'Привлечение за вчера')
    .setOption('width', 470).setOption('height', 280)
    .setOption('legend', { position: 'none' })
    .setOption('colors', [CFG.C.blue])
    .build();
  dash.insertChart(acq);
}

function hideRawSheets_() {
  try { getSheet_(CFG.SHEET.summary, 1).hideSheet(); } catch (e) {}
  try { getSheet_(CFG.SHEET.service, 6).hideSheet(); } catch (e) {}
}

function protectSheet_(sheet, description) {
  try {
    sheet.getProtections(SpreadsheetApp.ProtectionType.SHEET).forEach(function (p) { p.remove(); });
    sheet.protect().setDescription(description).setWarningOnly(true);
  } catch (e) {}
}

// ---------------------------------------------------------------------------------------
// Триггер раз в час
// ---------------------------------------------------------------------------------------
function installTrigger(silent) {
  ScriptApp.getProjectTriggers().forEach(function (t) {
    if (t.getHandlerFunction() === 'refreshDashboard') ScriptApp.deleteTrigger(t);
  });
  ScriptApp.newTrigger('refreshDashboard').timeBased().everyHours(1).create();
  if (!silent) {
    SpreadsheetApp.getUi().alert('Готово', 'Данные будут обновляться каждый час.', SpreadsheetApp.getUi().ButtonSet.OK);
  }
}
