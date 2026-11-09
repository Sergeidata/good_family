# Разбор экспорта Google Sheets (`Новая таблица.xlsx`)

> Это снимок **v1** дашборда (на формулах). Причина ошибок: книга с русской локалью
> парсит формулы с разделителем `;`, поэтому 50 из 50 формул с запятыми получили
> `#ERROR!`; уцелела одна без разделителей. В v2 формулы не используются.
> Актуальное состояние — `../../README.md`, `../../sheet_layout.md`.

Формулы читаются из `data_only=False`, кэш — из `data_only=True`.

Всего формул: 52; из них с ошибкой: 51.

## Формулы БЕЗ ошибки (что всё-таки распарсилось)

- `История!G2` — `=COUNTA($A$2:$A$1000)` → `2`

## Все ячейки с ошибкой

- `Дашборд!A2` — `="Данные за "&_Служебный!B4&" (вчера, UTC) · обновлено: "&_Служебный!B3&IF(_Служебный!B5="OK",""," · ⚠ "&_Служебный!B5)` → `'#ERROR!'` (fmt=General)
- `Дашборд!A6` — `=IFERROR(VLOOKUP("active_families_yesterday",'Сырые данные'!$A:$B,2,FALSE),"нет данных")` → `'#ERROR!'` (fmt=#,##0)
- `Дашборд!C6` — `=IFERROR(VLOOKUP("active_members_yesterday",'Сырые данные'!$A:$B,2,FALSE),"нет данных")` → `'#ERROR!'` (fmt=#,##0)
- `Дашборд!E6` — `=IFERROR(INDEX('Функции'!$D$2:$D$8,1),"нет данных")` → `'#ERROR!'` (fmt=General)
- `Дашборд!G6` — `=IFERROR(VLOOKUP("new_families_yesterday",'Сырые данные'!$A:$B,2,FALSE),"нет данных")` → `'#ERROR!'` (fmt=#,##0)
- `Дашборд!A7` — `=IFERROR("из "&VLOOKUP("total_families",'Сырые данные'!$A:$B,2,FALSE)&" семей · "&TEXT(VLOOKUP("active_families_yesterday",'Сырые данные'!$A:$B,2,FALSE)/VLOOKUP("total_families",'Сырые данные'!$A:$B,2,FALSE),"0%")&" активны","")` → `'#ERROR!'` (fmt=General)
- `Дашборд!C7` — `=IFERROR("всего участников: "&VLOOKUP("total_members",'Сырые данные'!$A:$B,2,FALSE),"")` → `'#ERROR!'` (fmt=General)
- `Дашборд!E7` — `=IFERROR("событий за вчера: "&INDEX('Функции'!$E$2:$E$8,1),"")` → `'#ERROR!'` (fmt=General)
- `Дашборд!G7` — `=IFERROR("новых участников: "&VLOOKUP("new_members_yesterday",'Сырые данные'!$A:$B,2,FALSE)&" · аккаунтов: "&VLOOKUP("new_accounts_yesterday",'Сырые данные'!$A:$B,2,FALSE),"")` → `'#ERROR!'` (fmt=General)
- `Дашборд!B11` — `=IFERROR(VLOOKUP($A11,'Функции'!$A:$C,2,FALSE),"")` → `'#ERROR!'` (fmt=#,##0)
- `Дашборд!C11` — `=IFERROR(VLOOKUP($A11,'Функции'!$A:$C,3,FALSE),"")` → `'#ERROR!'` (fmt=#,##0)
- `Дашборд!B12` — `=IFERROR(VLOOKUP($A12,'Функции'!$A:$C,2,FALSE),"")` → `'#ERROR!'` (fmt=#,##0)
- `Дашборд!C12` — `=IFERROR(VLOOKUP($A12,'Функции'!$A:$C,3,FALSE),"")` → `'#ERROR!'` (fmt=#,##0)
- `Дашборд!B13` — `=IFERROR(VLOOKUP($A13,'Функции'!$A:$C,2,FALSE),"")` → `'#ERROR!'` (fmt=#,##0)
- `Дашборд!C13` — `=IFERROR(VLOOKUP($A13,'Функции'!$A:$C,3,FALSE),"")` → `'#ERROR!'` (fmt=#,##0)
- `Дашборд!B14` — `=IFERROR(VLOOKUP($A14,'Функции'!$A:$C,2,FALSE),"")` → `'#ERROR!'` (fmt=#,##0)
- `Дашборд!C14` — `=IFERROR(VLOOKUP($A14,'Функции'!$A:$C,3,FALSE),"")` → `'#ERROR!'` (fmt=#,##0)
- `Дашборд!B15` — `=IFERROR(VLOOKUP($A15,'Функции'!$A:$C,2,FALSE),"")` → `'#ERROR!'` (fmt=#,##0)
- `Дашборд!C15` — `=IFERROR(VLOOKUP($A15,'Функции'!$A:$C,3,FALSE),"")` → `'#ERROR!'` (fmt=#,##0)
- `Дашборд!B16` — `=IFERROR(VLOOKUP($A16,'Функции'!$A:$C,2,FALSE),"")` → `'#ERROR!'` (fmt=#,##0)
- `Дашборд!C16` — `=IFERROR(VLOOKUP($A16,'Функции'!$A:$C,3,FALSE),"")` → `'#ERROR!'` (fmt=#,##0)
- `Дашборд!B20` — `=IFERROR(VLOOKUP("total_families",'Сырые данные'!$A:$B,2,FALSE),"нет данных")` → `'#ERROR!'` (fmt=#,##0)
- `Дашборд!B21` — `=IFERROR(VLOOKUP("active_families_yesterday",'Сырые данные'!$A:$B,2,FALSE),"нет данных")` → `'#ERROR!'` (fmt=#,##0)
- `Дашборд!C21` — `=IFERROR(TEXT(B21/B20,"0%")&" семей были активны","")` → `'#ERROR!'` (fmt=General)
- `Дашборд!B22` — `=IFERROR(VLOOKUP("total_members",'Сырые данные'!$A:$B,2,FALSE),"нет данных")` → `'#ERROR!'` (fmt=#,##0)
- `Дашборд!B23` — `=IFERROR(VLOOKUP("active_members_yesterday",'Сырые данные'!$A:$B,2,FALSE),"нет данных")` → `'#ERROR!'` (fmt=#,##0)
- `Дашборд!C23` — `=IFERROR(IF(B23>B22,"⚠ активных больше, чем участников","ok"),"")` → `'#ERROR!'` (fmt=General)
- `Дашборд!B24` — `=IFERROR(ROUND(B22/B20,2),"")` → `'#ERROR!'` (fmt=0.00)
- `Дашборд!B25` — `=IFERROR(C11,"")` → `'#ERROR!'` (fmt=#,##0)
- `Дашборд!B26` — `=IFERROR(C12,"")` → `'#ERROR!'` (fmt=#,##0)
- `Дашборд!C26` — `=IFERROR(TEXT(B26/B25,"0%")&" от созданных","")` → `'#ERROR!'` (fmt=General)
- `Дашборд!B27` — `=IFERROR(C13,"")` → `'#ERROR!'` (fmt=#,##0)
- `Дашборд!C27` — `=IFERROR(TEXT(B27/B26,"0%")&" от выполненных","")` → `'#ERROR!'` (fmt=General)
- `Дашборд!B28` — `=IFERROR(VLOOKUP("new_families_yesterday",'Сырые данные'!$A:$B,2,FALSE),"нет данных")` → `'#ERROR!'` (fmt=#,##0)
- `Дашборд!B29` — `=IFERROR(VLOOKUP("new_members_yesterday",'Сырые данные'!$A:$B,2,FALSE),"нет данных")` → `'#ERROR!'` (fmt=#,##0)
- `Дашборд!B30` — `=IFERROR(VLOOKUP("new_accounts_yesterday",'Сырые данные'!$A:$B,2,FALSE),"нет данных")` → `'#ERROR!'` (fmt=#,##0)
- `Дашборд!B34` — `=IFERROR('История'!$G$2&" дн.","")` → `'#ERROR!'` (fmt=General)
- `Дашборд!B35` — `=IFERROR(IF(VLOOKUP("tasks_done_yesterday",'Сырые данные'!$A:$B,2,FALSE)='История'!$H$2,"ok","⚠"),"нет данных")` → `'#ERROR!'` (fmt=General)
- `Дашборд!C35` — `=IFERROR("история: "&'История'!$H$2&" · summary: "&VLOOKUP("tasks_done_yesterday",'Сырые данные'!$A:$B,2,FALSE),"")` → `'#ERROR!'` (fmt=General)
- `Дашборд!B36` — `=IFERROR(IF(B23<=B22,"ok","⚠"),"")` → `'#ERROR!'` (fmt=General)
- `Дашборд!C36` — `=IFERROR("активных "&B23&" из "&B22&" участников","")` → `'#ERROR!'` (fmt=General)
- `Дашборд!B37` — `=IFERROR(IF(VLOOKUP("syncs_yesterday",'Сырые данные'!$A:$B,2,FALSE)=B23,"ok","⚠"),"")` → `'#ERROR!'` (fmt=General)
- `Дашборд!C37` — `=IFERROR("syncs "&VLOOKUP("syncs_yesterday",'Сырые данные'!$A:$B,2,FALSE)&" vs активных "&B23&" — считаются строки без member_id","")` → `'#ERROR!'` (fmt=General)
- `Дашборд!B38` — `=IFERROR(IF(VLOOKUP("achievements_yesterday",'Сырые данные'!$A:$B,2,FALSE)=0,"0","ok"),"")` → `'#ERROR!'` (fmt=General)
- `Дашборд!B39` — `=IFERROR(IF(VLOOKUP("garden_changes_yesterday",'Сырые данные'!$A:$B,2,FALSE)=0,"0","ok"),"")` → `'#ERROR!'` (fmt=General)
- `Дашборд!B40` — `=скрыт` → `'#NAME?'` (fmt=General)
- `Функции!D2` — `=IFERROR(SORT(FILTER($A$2:$B$100,$A$2:$A$100<>"",LEFT($A$2:$A$100,5)<>"Новые"),2,FALSE),"")` → `'#ERROR!'` (fmt=General)
- `История!H2` — `=IFERROR(INDEX($E$2:$E$1000,COUNTA($A$2:$A$1000)),"")` → `'#ERROR!'` (fmt=General)
- `История!I2` — `=IFERROR(INDEX($A$2:$A$1000,COUNTA($A$2:$A$1000)),"")` → `'#ERROR!'` (fmt=General)
- `Приложения!C2` — `=ARRAYFORMULA(IF($B$2:$B$100="","",ROUND($B$2:$B$100/60,1)))` → `'#ERROR!'` (fmt=General)
- `_Служебный!A4` — `=IFERROR(VLOOKUP("date_measured",'Сырые данные'!A:B,2,FALSE),"нет данных")` → `'#ERROR!'` (fmt=General)

## Признаки, по которым можно судить о причине

- содержат запятую-разделитель аргументов: формул 50, из них с ошибкой 50
- содержат точку с запятой: формул 0, из них с ошибкой 0
- содержат русские имена функций: формул 0, из них с ошибкой 0
- содержат _xlfn.: формул 0, из них с ошибкой 0
- содержат умные кавычки: формул 0, из них с ошибкой 0
- содержат двойные кавычки: формул 50, из них с ошибкой 50

## Данные листов (значения и типы)

### Дашборд (rows=46, cols=8)
- A1='Good Family · продуктовая аналитика'(str,fmt=General)
- A2='#ERROR!'(str,fmt=General)
- A4='КЛЮЧЕВЫЕ KPI ЗА ВЧЕРА'(str,fmt=General)
- A5='АКТИВНЫЕ СЕМЬИ (ВЧЕРА)'(str,fmt=General) | C5='АКТИВНЫЕ ПОЛЬЗОВАТЕЛИ (ВЧЕРА)'(str,fmt=General) | E5='ТОП-ФУНКЦИЯ (ВЧЕРА)'(str,fmt=General) | G5='НОВЫЕ СЕМЬИ (ВЧЕРА)'(str,fmt=General)
- A6='#ERROR!'(str,fmt=#,##0) | C6='#ERROR!'(str,fmt=#,##0) | E6='#ERROR!'(str,fmt=General) | G6='#ERROR!'(str,fmt=#,##0)
- A7='#ERROR!'(str,fmt=General) | C7='#ERROR!'(str,fmt=General) | E7='#ERROR!'(str,fmt=General) | G7='#ERROR!'(str,fmt=General)
- A9='ХОРОШИЕ ДЕЛА, САД, ДОСТИЖЕНИЯ — ВЧЕРА И ВСЕГО'(str,fmt=General)
- A10='Функция'(str,fmt=General) | B10='Вчера'(str,fmt=General) | C10='Всего'(str,fmt=General) | D10='Комментарий'(str,fmt=General)
- A11='Хорошие дела: создано'(str,fmt=General) | B11='#ERROR!'(str,fmt=#,##0) | C11='#ERROR!'(str,fmt=#,##0) | D11='задание придумано родителем'(str,fmt=General)
- A12='Хорошие дела: выполнено ребёнком'(str,fmt=General) | B12='#ERROR!'(str,fmt=#,##0) | C12='#ERROR!'(str,fmt=#,##0) | D12='ребёнок нажал «Я сделал»'(str,fmt=General)
- A13='Хорошие дела: подтверждено родителем'(str,fmt=General) | B13='#ERROR!'(str,fmt=#,##0) | C13='#ERROR!'(str,fmt=#,##0) | D13='родитель принял → начислены звёзды'(str,fmt=General)
- A14='Достижения: получено'(str,fmt=General) | B14='#ERROR!'(str,fmt=#,##0) | C14='#ERROR!'(str,fmt=#,##0) | D14='личные/групповые достижения'(str,fmt=General)
- A15='Семейный сад: изменения'(str,fmt=General) | B15='#ERROR!'(str,fmt=#,##0) | C15='#ERROR!'(str,fmt=#,##0) | D15='уровень/прогресс сада'(str,fmt=General)
- A16='Награды: запрошено'(str,fmt=General) | B16='#ERROR!'(str,fmt=#,##0) | C16='#ERROR!'(str,fmt=#,##0) | D16='ребёнок обменял звёзды на награду'(str,fmt=General)
- A18='ВОРОНКА И ОХВАТ'(str,fmt=General)
- A19='Метрика'(str,fmt=General) | B19='Значение'(str,fmt=General) | C19='Комментарий'(str,fmt=General)
- A20='Семей всего'(str,fmt=General) | B20='#ERROR!'(str,fmt=#,##0)

### Сырые данные (rows=17, cols=2)
- A1='metric'(str,fmt=General) | B1='value'(str,fmt=General)
- A2='date_measured'(str,fmt=General) | B2=datetime.datetime(2026, 11, 8, 0, 0)(datetime,fmt=yyyy-mm-dd)
- A3='active_families_yesterday'(str,fmt=General) | B3=5.0(float,fmt=General)
- A4='active_members_yesterday'(str,fmt=General) | B4=7.0(float,fmt=General)
- A5='total_families'(str,fmt=General) | B5=7.0(float,fmt=General)
- A6='total_members'(str,fmt=General) | B6=11.0(float,fmt=General)
- A7='total_accounts'(str,fmt=General) | B7=6.0(float,fmt=General)
- A8='new_families_yesterday'(str,fmt=General) | B8=2.0(float,fmt=General)
- A9='new_members_yesterday'(str,fmt=General) | B9=2.0(float,fmt=General)
- A10='new_accounts_yesterday'(str,fmt=General) | B10=0.0(float,fmt=General)
- A11='syncs_yesterday'(str,fmt=General) | B11=7.0(float,fmt=General)
- A12='tasks_created_yesterday'(str,fmt=General) | B12=22.0(float,fmt=General)
- A13='tasks_done_yesterday'(str,fmt=General) | B13=8.0(float,fmt=General)
- A14='tasks_approved_yesterday'(str,fmt=General) | B14=7.0(float,fmt=General)
- A15='achievements_yesterday'(str,fmt=General) | B15=0.0(float,fmt=General)
- A16='garden_changes_yesterday'(str,fmt=General) | B16=0.0(float,fmt=General)
- A17='rewards_requested_yesterday'(str,fmt=General) | B17=0.0(float,fmt=General)

### Функции (rows=11, cols=5)
- A1='feature'(str,fmt=General) | B1='yesterday'(str,fmt=General) | C1='total'(str,fmt=General) | D1='Функция (по популярности)'(str,fmt=General) | E1='Вчера'(str,fmt=General)
- A2='Синхронизация экранного времени'(str,fmt=General) | B2=7.0(float,fmt=General) | C2=27.0(float,fmt=General) | D2='#ERROR!'(str,fmt=General)
- A3='Хорошие дела: создано'(str,fmt=General) | B3=22.0(float,fmt=General) | C3=25.0(float,fmt=General)
- A4='Хорошие дела: выполнено ребёнком'(str,fmt=General) | B4=8.0(float,fmt=General) | C4=11.0(float,fmt=General)
- A5='Хорошие дела: подтверждено родителем'(str,fmt=General) | B5=7.0(float,fmt=General) | C5=8.0(float,fmt=General)
- A6='Достижения: получено'(str,fmt=General) | B6=0.0(float,fmt=General) | C6=0.0(float,fmt=General)
- A7='Семейный сад: изменения'(str,fmt=General) | B7=0.0(float,fmt=General) | C7=0.0(float,fmt=General)
- A8='Награды: запрошено'(str,fmt=General) | B8=0.0(float,fmt=General) | C8=0.0(float,fmt=General)
- A9='Новые семьи'(str,fmt=General) | B9=2.0(float,fmt=General) | C9=7.0(float,fmt=General)
- A10='Новые участники'(str,fmt=General) | B10=2.0(float,fmt=General) | C10=11.0(float,fmt=General)
- A11='Новые аккаунты'(str,fmt=General) | B11=0.0(float,fmt=General) | C11=6.0(float,fmt=General)

### История (rows=3, cols=9)
- A1='date'(str,fmt=General) | B1='active_members'(str,fmt=General) | C1='active_families'(str,fmt=General) | D1='syncs'(str,fmt=General) | E1='tasks_done'(str,fmt=General) | F1='achievements'(str,fmt=General) | G1='Дней с данными'(str,fmt=General) | H1='Задания в последний день'(str,fmt=General) | I1='Последняя дата'(str,fmt=General)
- A2=datetime.datetime(2026, 11, 7, 0, 0)(datetime,fmt=yyyy-mm-dd) | B2=9.0(float,fmt=General) | C2=6.0(float,fmt=General) | D2=9.0(float,fmt=General) | E2=1.0(float,fmt=General) | F2=0.0(float,fmt=General) | G2=2(int,fmt=General) | H2='#ERROR!'(str,fmt=General) | I2='#ERROR!'(str,fmt=General)
- A3=datetime.datetime(2026, 11, 8, 0, 0)(datetime,fmt=yyyy-mm-dd) | B3=7.0(float,fmt=General) | C3=5.0(float,fmt=General) | D3=7.0(float,fmt=General) | E3=8.0(float,fmt=General) | F3=0.0(float,fmt=General)

### Достижения (rows=1, cols=3)
- A1='achievement_key'(str,fmt=General) | B1='period'(str,fmt=General) | C1='count'(str,fmt=General)

### Приложения (rows=16, cols=3)
- A1='app'(str,fmt=General) | B1='minutes_yesterday'(str,fmt=General) | C1='Часы (суммарно)'(str,fmt=General)
- A2='com.example.family_focus'(str,fmt=General) | B2=917.0(float,fmt=General) | C2='#ERROR!'(str,fmt=General)
- A3='ru.hh.android'(str,fmt=General) | B3=845.0(float,fmt=General)
- A4='ru.gosuslugi.auto'(str,fmt=General) | B4=473.0(float,fmt=General)
- A5='ru.beru.android'(str,fmt=General) | B5=465.0(float,fmt=General)
- A6='ru.belkacar.belkacar'(str,fmt=General) | B6=353.0(float,fmt=General)
- A7='ru.yandex.mail'(str,fmt=General) | B7=284.0(float,fmt=General)
- A8='ru.mail.mailapp'(str,fmt=General) | B8=256.0(float,fmt=General)
- A9='com.kabam.marvelbattle'(str,fmt=General) | B9=188.0(float,fmt=General)
- A10='ru.leroymerlin.mobile'(str,fmt=General) | B10=180.0(float,fmt=General)
- A11='youdrive.today'(str,fmt=General) | B11=172.0(float,fmt=General)
- A12='Messenger'(str,fmt=General) | B12=129.0(float,fmt=General)
- A13='App'(str,fmt=General) | B13=117.0(float,fmt=General)
- A14='Android'(str,fmt=General) | B14=97.0(float,fmt=General)
- A15='ru.yandex.searchplugin'(str,fmt=General) | B15=69.0(float,fmt=General)
- A16='Youtube'(str,fmt=General) | B16=63.0(float,fmt=General)

### _Служебный (rows=6, cols=6)
- A1='СЛУЖЕБНЫЙ ЛИСТ — НЕ УДАЛЯТЬ'(str,fmt=General) | F1='Диагностика'(str,fmt=General)
- A2='Здесь: время обновления, дата данных и (опционально) URL для ручного режима IMPORTDATA.'(str,fmt=General)
- A3='Последнее обновление (МСК)'(str,fmt=General) | B3=datetime.datetime(2026, 11, 9, 16, 13)(datetime,fmt=dd.mm.yyyy h:mm)
- A4='#ERROR!'(str,fmt=General)
- A5='Статус'(str,fmt=General) | B5='OK'(str,fmt=General)
- A6='Источник'(str,fmt=General) | B6='http://89.108.66.36/export_stats'(str,fmt=General)

### Лист1 (rows=1, cols=1)
