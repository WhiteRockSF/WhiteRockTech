global without sharing class MonthlySupportTaskChecklistCreation {
    @InvocableMethod(
        label='Create Checklist for Monthly Support Task'
    )
    public static List<ActionResult> createChecklistsWithItems(List<ChecklistsCreationActionRequest> requestList) {

        List<MonthSupportCheckList__mdt> checklistWithItems = [SELECT Id, DeveloperName, MasterLabel, Check_List_Items__c FROM MonthSupportCheckList__mdt];
        List<Id> tasksIds = requestList[0].tasksIds;

        List<ActionResult> results = new List<ActionResult>();
        ActionResult result = new ActionResult();

        try {
            List<TASKRAY__trChecklistGroup__c> checklistsToCreate = generateChecklists(tasksIds, checklistWithItems);
            
            if(checklistsToCreate.size() > 0) {
                Database.SaveResult[] lsr = Database.insert(checklistsToCreate, false);

                Map<String, List<TASKRAY__trChecklistGroup__c>> checklistsByName = new Map<String, List<TASKRAY__trChecklistGroup__c>>();
                
                for(MonthSupportCheckList__mdt checklistData : checklistWithItems) {

                    List<TASKRAY__trChecklistGroup__c> checklist = (checklistsByName.containsKey(checklistData.DeveloperName))
                    ? checklistsByName.get(checklistData.DeveloperName)
                    : new List<TASKRAY__trChecklistGroup__c>();

                    for(TASKRAY__trChecklistGroup__c createdList : checklistsToCreate) {
                        if(createdList.Name == checklistData.MasterLabel) {
                            checklist.add(createdList);
                        }
                    }

                    checklistsByName.put(checklistData.DeveloperName, checklist);
                }

                List<TASKRAY__trChecklistItem__c> checklistItems = generateChecklistsItems(checklistsByName, checklistWithItems);
                
                result.creationSucceeded = true;
            }
        } catch (Exception e) {
            result.creationSucceeded = false;
        }

        results.add(result);
        return results;
    }

    private static List<TASKRAY__trChecklistGroup__c> generateChecklists(List<Id> tasksIdsList, List<MonthSupportCheckList__mdt> checklistWithItems) {
        List<TASKRAY__trChecklistGroup__c> tasksChecklists = new List<TASKRAY__trChecklistGroup__c>();

        for(Id taskId : tasksIdsList) {
            for(MonthSupportCheckList__mdt checkListData : checklistWithItems) {
                tasksChecklists.add(new TASKRAY__trChecklistGroup__c(Name = checkListData.MasterLabel, TASKRAY__TaskForGroup__c = taskId));
            }
        }

        return tasksChecklists;
    }

    private static List<TASKRAY__trChecklistItem__c> generateChecklistsItems(Map<String, List<TASKRAY__trChecklistGroup__c>> createdChecklists, List<MonthSupportCheckList__mdt> checklistWithItemsData) {
        List<TASKRAY__trChecklistItem__c> checklistItems = new List<TASKRAY__trChecklistItem__c>();

        for(MonthSupportCheckList__mdt checkListData : checklistWithItemsData) {

            List<TASKRAY__trChecklistGroup__c> checklists = createdChecklists.get(checkListData.DeveloperName);
            if(checklists == null && checklists.size() == 0) {
                continue;
            }

            List<String> itemsNames = checkListData.Check_List_Items__c.split('\n');

            for(TASKRAY__trChecklistGroup__c checklist : checklists) {
                if(checklist.Id == null) {
                    continue;
                }

                
                for(String itemName : itemsNames) {
                    String shortName = (itemName.length() > 80) ? itemName.abbreviate(80) : itemName;
                    checklistItems.add(new TASKRAY__trChecklistItem__c(
                        Name = shortName, 
                        TASKRAY__trLongName__c = itemName,
                        TASKRAY__trChecklistGroup__c = checklist.Id,
                        TASKRAY__Project_Task__c = checklist.TASKRAY__TaskForGroup__c ));
                }
                
            }
        }

        if(checklistItems.size() > 0) {
            Database.SaveResult[] lsr = Database.insert(checklistItems, false);
            for (Database.SaveResult sr : lsr) {
            if (sr.isSuccess()) {
                // Operation was successful, so get the ID of the record that was processed
                System.debug('Successfully inserted Checklist Item. Checklist Item ID: ' + sr.getId());
            }
            else {
                // Operation failed, so get all errors                
                for(Database.Error err : sr.getErrors()) {
                    System.debug('The following error has occurred.');                    
                    System.debug(err.getStatusCode() + ': ' + err.getMessage());
                    System.debug('Checklist Item fields that affected this error: ' + err.getFields());
                }
            }
        }
        }
        return checklistItems;
    }

    public class ChecklistsCreationActionRequest {
        @InvocableVariable(required=true)
        public List<Id> tasksIds;
    }

    public class ActionResult {
        @InvocableVariable(label='True if creation succeeded')
        public boolean creationSucceeded;
    }
}