# HubSpot Buyer Intent - New Features

## ✅ Implemented Features

### 1. Click Company Name → Navigate to Account/Lead
- **Auto-matching**: Companies are automatically matched to Salesforce Accounts or Leads
- **Matching logic**:
  - First tries to match by Company Name
  - Then tries to match by Website Domain
  - Prioritizes Account over Lead
- **Result**: Clicking company name takes you to the Salesforce record (if found) or website (if not found)

### 2. Dynamic Totals Based on Time Frame Filter
- **Total Companies**: Updates based on time frame filter
- **Total Page Views**: Sums page views for visible companies only
- **Total Unique Visitors**: Sums unique visitors for visible companies only
- All totals react to both time frame AND intent level filters

### 3. Visitor Intent Details on Account/Lead Pages
- **New Component**: `buyerIntentRecordDetail`
- **Shows**:
  - Page Views
  - Unique Visitors  
  - Last Visit Date
  - Industry
  - Company Website
- **How to Add**:
  1. Go to Account or Lead record page
  2. Edit Page in Lightning App Builder
  3. Add "HubSpot Visitor Intent" component
  4. Save & Activate

## How It Works

### Salesforce Matching
The system queries Salesforce for:
```apex
// Accounts
SELECT Id, Name, Website FROM Account 
WHERE Name IN :companyNames OR Website IN :domains

// Leads (non-converted only)
SELECT Id, Company, Website FROM Lead 
WHERE Company IN :companyNames OR Website IN :domains
AND IsConverted = false
```

### Link Generation
- If Salesforce ID found: `/{SalesforceId}` → Opens record in Salesforce
- If no match: `{Website}` → Opens company website

## Deployment

Deploy all files:
```bash
# Main component
sfdx force:source:deploy -p force-app/main/default/lwc/buyerIntent

# Record detail component (NEW)
sfdx force:source:deploy -p force-app/main/default/lwc/buyerIntentRecordDetail

# Updated Apex controller
sfdx force:source:deploy -p force-app/main/default/classes/BuyerIntentController.cls
```

## Usage

### Main Component
- Place on Home Page or App Page
- Click company name to navigate to Salesforce record
- Totals update automatically with filters

### Record Detail Component
- Add to Account or Lead Lightning Record Page
- Shows visitor intent for that specific record
- Refresh button to update data

## Notes
- Matching is case-insensitive
- Website domains are normalized (removes http://, https://, www.)
- If multiple matches exist, first match is used
- Maximum 1000 Accounts and 1000 Leads are queried for performance
