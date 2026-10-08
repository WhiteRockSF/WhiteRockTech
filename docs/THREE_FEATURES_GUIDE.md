# HubSpot Buyer Intent - Three Key Features Guide

## 1. Click Company Name → Navigate to Account/Lead

**How it works:**
- Companies from HubSpot are automatically matched with Salesforce Accounts and Leads
- Matching is done by:
  - Company Name (exact match, case-insensitive)
  - Website Domain (normalized, removes http://, https://, www.)
- Priority: Account by name → Account by domain → Lead by name → Lead by domain

**Result:**
- If match found: Click opens the Salesforce Account or Lead record
- If no match: Click opens the company website in new tab

**No setup required** - matching happens automatically when data loads.

---

## 2. Dynamic Totals Based on Time Frame Filter

**How it works:**
The three stat cards at the top update automatically:
- **Filtered Companies**: Shows count of companies matching the time frame filter ✅
- **Total Page Views**: Sum of page views for visible companies ⚠️ **All-time values**
- **Total Unique Visitors**: Sum of unique visitors for visible companies ⚠️ **All-time values**

**Important Limitation:**
HubSpot's Companies API returns **cumulative (all-time)** values for:
- `hs_analytics_num_page_views`
- `hs_analytics_num_visits`

These fields do NOT have date-range breakdowns. Therefore:
- ✅ The **number of companies** changes with time filter (only shows companies visited in that period)
- ⚠️ The **page views per company** remain the same (shows lifetime total)
- ⚠️ The **unique visitors per company** remain the same (shows lifetime total)

**Example:**
- Filter: "This week"
- Shows: Companies that visited this week
- Page Views: Shows **all-time** page views for those companies (not just this week's views)

**To get time-segmented analytics:**
Would require HubSpot Analytics Events API with `analytics.behavioral_events.read` scope, which provides individual page view events that can be aggregated by date range. This is significantly more complex and may have rate limits.

---

## 3. Show Visitor Intent Details on Account/Lead Pages

**Component:** `buyerIntentRecordDetail`

**What it shows:**
- Page Views count
- Unique Visitors count
- Last Visit date/time
- Industry
- Company Website (clickable link)
- Refresh button to reload data

**How to add to Account/Lead pages:**

1. Navigate to any Account or Lead record
2. Click the gear icon ⚙️ → **Edit Page**
3. In the Lightning App Builder (left sidebar):
   - Find **"HubSpot Visitor Intent"** component
   - Drag it onto the page (recommended: right column)
4. Click **Save**
5. Click **Activate** → Choose activation options
6. Click **Save** again

**Result:**
- Component appears on all Account/Lead record pages
- Automatically finds matching HubSpot data for that record
- Shows "No visitor intent data found" if no match exists

---

## Quick Start

1. **Deploy all components:**
```bash
sfdx force:source:deploy -p force-app/main/default/lwc/buyerIntent
sfdx force:source:deploy -p force-app/main/default/lwc/buyerIntentRecordDetail
sfdx force:source:deploy -p force-app/main/default/classes/BuyerIntentController.cls
```

2. **Test Feature #1 (Click to navigate):**
   - Open main Buyer Intent component
   - Click any company name
   - Should open Salesforce record (if exists) or website

3. **Test Feature #2 (Dynamic totals):**
   - Change Time Frame filter dropdown
   - Watch stat cards update automatically

4. **Test Feature #3 (Record details):**
   - Add component to Account/Lead page (instructions above)
   - Navigate to an Account/Lead
   - See visitor intent data in component

---

## Notes

- **Matching is automatic** - no manual linking required
- **Case-insensitive** - "White Rock" matches "white rock"
- **Domain normalization** - "https://www.example.com" matches "example.com"
- **Max 1000 records** - queries limited to 1000 Accounts and 1000 Leads for performance
- **Non-converted Leads only** - converted Leads are excluded from matching
