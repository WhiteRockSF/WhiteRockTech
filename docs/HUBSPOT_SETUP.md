# HubSpot Buyer Intent - Быстрая настройка

## Что делает компонент
Отображает список компаний из HubSpot, которые посещали ваш сайт (Buyer Intent данные).

## Настройка за 5 шагов

### 1. Создать Private App в HubSpot
1. HubSpot → Settings → Integrations → **Private Apps**
2. **Create a private app**
3. Name: "Salesforce Integration"
4. Scopes → выбрать:
   - ✓ `crm.objects.companies.read` (обязательно!)
   - ⚠️ НЕ `crm.schemas.companies.read` (это другое)
5. **Create app** → скопировать **Access Token**
   - Формат: `pat-na1-xxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

### 2. Создать Named Credential в Salesforce (Legacy)

1. Setup → **Named Credentials** → **New Legacy**
2. Заполнить:
   - Label: `HubSpot`
   - Name: `HubSpot`
   - URL: `https://api.hubapi.com`
   - Identity Type: **Named Principal**
   - Authentication Protocol: **No Authentication**
   - Generate Authorization Header: ✗ (НЕ отмечать)
3. Save
4. После сохранения → Edit → прокрутить вниз до **Custom Headers**
5. Добавить заголовок:
   - Header Name: `Authorization`
   - Header Value: `Bearer ВАШ_HUBSPOT_ACCESS_TOKEN`
   - Например: `Bearer <YOUR_HUBSPOT_ACCESS_TOKEN>`
6. Save

### 3. Добавить Remote Site
1. Setup → **Remote Site Settings** → **New Remote Site**
2. Заполнить:
   - Name: `HubSpot_API`
   - URL: `https://api.hubapi.com`
   - Active: ✓
3. Save

### 4. Развернуть компонент
```bash
sfdx force:source:deploy -p force-app/main/default/lwc/buyerIntent
sfdx force:source:deploy -p force-app/main/default/classes/BuyerIntentController.cls
```

### 5. Добавить на страницу
1. Lightning App Builder → Edit Page
2. Найти компонент: **"Buyer Intent - HubSpot Visitor Data"**
3. Перетащить на страницу
4. Save & Activate

## Готово!
Нажмите "Test Connection" для проверки, затем "Refresh" для загрузки данных.

## Возможные ошибки

**401 Unauthorized** → Проверьте Access Token в Named Credential  
**Unauthorized endpoint** → Проверьте Remote Site Settings  
**403 Forbidden** → Проверьте scopes в Private App  
**Пустой список** → В HubSpot нет компаний с visitor activity
