# WhiteRockTech — Salesforce

Salesforce DX project for **WhiteRockTech** (WhiteRock).

WhiteRock internal Salesforce org (TaskRay / delivery).

Source of truth for shared branches is the live org metadata:

| Branch | Org | Role |
|--------|-----|------|
| `production` | `PROD_TaskRay` | Production |
| `uat` | (UAT sandbox when available) | QA / client test |

## Features / what’s in this org

- **Custom objects (17)**: Account_Plan__c, Auth0Connect__c, Credential__c, LinkedIn_Ad_Metric__c, LinkedIn_Api_Secret__c, LinkedIn_Integration_Settings__c, Login_History__c, Managed_Services__c, OrgSettings__c, Production__c, Production_Task__c, Projected_Time__c (+5 more)
- **Apex classes (69)**: Auth0Controller, Auth0ControllerTest, BuyerIntentController, BuyerIntentControllerTest, caseEditorController, caseEditorControllerTest, ChangePasswordController, ChangePasswordControllerTest, CommunitiesLandingController, CommunitiesLandingControllerTest (+59 more)
- **Triggers (4)**: OpportunityTrigger, slack_Production, slack_TaskRay_Task, TaskRayProjectTaskTrigger
- **Flows (58)**: AirCall_SMS_Received, AirCall_Type_and_Category, Assets, Auto_Create_Ramon_Follow_Up, Cadence_Assignment, Cadence_Assignment_Prod, Case, Case_Account_and_Owner, Case_Approval_Process, Case_emails (+48 more)
- **LWC (19)**: buyerIntent, buyerIntentRecordDetail, caseEditor, closeCase, customFormattedTime, datatable, datatableBase, datatablePicklistField, engagementReport, header (+9 more)
- **Aura (2)**: caseEditorLwc, closeLWC
- **Visualforce pages**: 31
- **Lightning pages (FlexiPage)**: 46
- **Permission sets**: 17

## Workflow

1. Branch from `production` (or `uat` once it diverges for QA work).
2. Develop and validate in a sandbox / scratch as needed.
3. Promote through `uat` then `production`.

Always pass `--target-org` explicitly. Prefer narrow manifests / paths for day-to-day deploys.

## Repo layout

- `force-app/` — Salesforce metadata
- `manifest/` — deploy/retrieve package.xml files
- `scripts/` — Apex / utility scripts (when present)

## Baseline

`production` and `uat` were initialized as an identical first commit from a full custom-metadata retrieve of **PROD_TaskRay** (`Initial commit from PROD_TaskRay`).
