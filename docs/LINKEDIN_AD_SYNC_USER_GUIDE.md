# LinkedIn Ad Metrics → HubSpot — инструкция для пользователя

## Что это делает

Компонент **LinkedIn Ad Sync** загружает демографию по компаниям из LinkedIn (Professional demographics / Company Name Segment), сохраняет её в Salesforce и затем отправляет метрики в **HubSpot Companies**.

Поток:

1. Данные попадают в Salesforce (`LinkedIn Ad Metric`).
2. По кнопке или по расписанию запускается batch в HubSpot.
3. HubSpot-компания ищется **по точному имени**. Новые компании автоматически не создаются.

Дубликаты не плодятся: одна комбинация **Campaign Name + Company Name** обновляется, а не создаётся заново.

---

## Где открыть

В Salesforce откройте вкладку **LinkedIn Ad Sync** (или приложение, куда добавлен компонент).

Две вкладки:

| Вкладка | Назначение |
|---------|------------|
| **Sync** | Кампания, даты, CSV / API fetch, таблица метрик, Push to HubSpot |
| **API Settings** | Токены LinkedIn/HubSpot, автосинк, расписание |

---

## Вкладка Sync

### Поля кампании

| Поле | Что указать |
|------|-------------|
| **Campaign Name** | Имя кампании/ad set, как в Campaign Manager (обязательно) |
| **LinkedIn Campaign Id** | Числовой id из URL или из строки ad set |
| **Report Start** | Начало периода для API |
| **Report End** | Конец периода. **Пусто = всегда «сегодня»** |

**Как взять Campaign Id**

В Campaign Manager откройте кампанию. В URL будет что-то вроде:

`.../accounts/506515554/campaigns?...&campaignIds=[704412604]`

- Account: `506515554`
- Campaign / Ad set id: `704412604` ← это и есть **LinkedIn Campaign Id**

Кнопка **Save Sync Defaults** сохраняет name, id и даты, чтобы при следующем открытии они подставились. Пустой Report End тоже можно сохранить — тогда fetch всегда будет до «сегодня».

---

### Вариант A — загрузка CSV

1. В Campaign Manager: **Export → Report type: Professional demographics**.
2. В Sync: укажите **Campaign Name** (и при желании Campaign Id).
3. Выберите файл CSV.
4. Строки **Company Name Segment** попадут в таблицу **Stored metrics** (`Source = CSV Upload`).

---

### Вариант B — Fetch from LinkedIn API

1. Заполните Campaign Name + Campaign Id.
2. Укажите даты (или оставьте End пустым = сегодня).
3. Нажмите **Fetch from LinkedIn API**.

В toast будет видно, сколько строк получено, например:

- `LinkedIn: 97 rows` — данные пришли.
- `Company names resolved: 97/97` — id компаний превращены в имена.
- `0 rows` — за период/кампанию LinkedIn вернул пустой ответ (проверьте id и даты).

В таблице `Source = LinkedIn API`.

---

### Push to HubSpot (Batch)

1. Убедитесь, что в таблице есть строки (CSV или API).
2. Нажмите **Push to HubSpot (Batch)**.
3. Дождитесь статуса batch внизу.

Статусы в колонке **HubSpot Status**:

| Статус | Значение |
|--------|----------|
| **Pending** | Ещё не синкали / ждут batch |
| **Synced** | Метрики записаны в найденную HubSpot Company |
| **Skipped** | Компания с таким именем в HubSpot не найдена |
| **Failed** | Ошибка (смотрите **HubSpot Error**) |

Важно: имя компании в Salesforce должно **точно совпадать** с `name` в HubSpot.

---

## Вкладка API Settings

### LinkedIn

1. Вставьте **Access Token** (для длинных токенов включите **Use LinkedIn Named Credential** — токен хранится в защищённом объекте).
2. При наличии: **Refresh Token**, **Client Id**, **Client Secret** — для автообновления токена.
3. Укажите **LinkedIn Ad Account URN**, например: `urn:li:sponsoredAccount:506515554`.
4. **LinkedIn API Version** — обычно оставляйте значение по умолчанию (например `202607`).
5. **Save Settings**.
6. **Test LinkedIn** — проверка доступа к API.
7. **Refresh LinkedIn Token** — ручное обновление access token.

### HubSpot

1. **HubSpot Access Token** (Private App) **или** Named Credential.
2. В HubSpot на Company должны быть свойства для метрик (impressions / clicks / conversions / campaign) — как в Custom Metadata **LinkedIn HubSpot Config**.
3. **Test HubSpot**.
4. **HubSpot Batch Size** — размер batch (например 50).

### Автосинк каждый день

1. Включите **Auto Sync Enabled**.
2. **Auto Sync Lookback Days** — за сколько дней назад тянуть данные.
3. **Daily run hour** — час запуска (0–23, timezone Salesforce org).
4. Убедитесь, что заполнены **Default Campaign Name / Id** (на Sync или в API Settings).
5. Нажмите **Schedule Daily Job**.

Статус job (Active / Next run / список кампаний) показывается в блоке расписания.  
**Stop Daily Job** — останавливает job и выключает Auto Sync.

Ежедневный job:

1. Тянет LinkedIn API по кампаниям из defaults + active Custom Metadata **LinkedIn Scheduled Campaign**.
2. Затем запускает HubSpot batch.

---

## Таблица Stored metrics

| Колонка | Смысл |
|---------|--------|
| Company | Имя компании (после API — через lookup организаций) |
| Impressions / Clicks / Conversions | Метрики |
| HubSpot Status / Error | Результат синка |
| Source | `CSV Upload` или `LinkedIn API` |

---

## Типовой сценарий «с нуля»

1. **API Settings** → токены LinkedIn + Ad Account URN + HubSpot → Save → Test LinkedIn / Test HubSpot.
2. **Sync** → Campaign Name + Campaign Id → Save Sync Defaults.
3. **Fetch from LinkedIn API** (или CSV).
4. Проверьте таблицу: имена компаний, не id.
5. **Push to HubSpot (Batch)**.
6. При необходимости: Auto Sync + **Schedule Daily Job**.

---

## Частые вопросы

**Fetch «успешен», но в таблице старый CSV?**  
Смотрите toast: если `0 rows` — API за период ничего не вернул. Если `N rows` и `Source = LinkedIn API` — это новые/обновлённые строки.

**В Company одни числа (id)?**  
API отдал organization id без имени. После исправления lookup toast должен показывать `Company names resolved: N/N`. Сделайте Fetch ещё раз. Старые строки с id можно удалить вручную.

**HubSpot = Skipped?**  
Нет Company с таким же `name`. Создайте/переименуйте в HubSpot или поправьте имя в LinkedIn/CSV.

**HubSpot = Failed: property doesn't exist?**  
В HubSpot нет нужных company properties — создайте их (или расширьте scopes Private App и создайте через скрипт/UI).

**Report End не остаётся пустым?**  
Очистите поле → **Save Sync Defaults**. Пустой End = «сегодня» при каждом Fetch.

**Какой id кампании брать?**  
Тот, что в URL `campaignIds=[...]` / в строке Ad set в Campaign Manager — не Campaign Group id.

---

## Права и доступы (кратко)

- LinkedIn token с доступом к Advertising / Ad Analytics (и при refresh — partner OAuth).
- HubSpot Private App с правом читать/писать Companies (и свойства).
- Пользователь Salesforce с доступом к вкладке и объектам LinkedIn Ad Metric / Settings.
