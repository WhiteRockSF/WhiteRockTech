public with sharing class OpportunityTriggerHandler {
    public void execute()
    {
        if (Trigger.operationType == TriggerOperation.BEFORE_UPDATE) 
        {
            this.beforeUpdate((List<Opportunity>) Trigger.new, (Map<Id, Opportunity>) Trigger.oldMap);
        }       
    }
    private void beforeUpdate(List<Opportunity> opps, Map<Id, Opportunity> oldMapOpps) {
        Set<String> oppIds = new Set<String>();
        for(Opportunity opp : opps) {
            if(opp.StageName != oldMapOpps.get(opp.Id).StageName && opp.StageName == 'Win & Transition') {
                oppIds.add(opp.Id);
            }
        }  
        System.debug(oppIds);
        if(oppIds.size() > 0) {
            createTaskRecords(oppIds);
        }
    }


    private void createTaskRecords(Set<String> oppIds) {

        Map<Id, Id> oppToProject = new Map<Id, Id>();
        List<Opportunity> opps = [
            SELECT Id , AccountId, Type__c, TaskRay_Parent__c, Name,
                (SELECT Id, Parent_Service_ID__c, Service_Name_Text__c, Product2Id, Quantity, Discount, TotalPrice, Description,
                    UnitPrice, ListPrice, ServiceDate, Estimated_Start_Date__c, Estimated_End_Date__c, Estimated_Hours_to_Complete__c,
                    Annual_Hours__c, Contract_or_Internal__c, Product2.Parent_Service__r.Name FROM OpportunityLineItems)
            FROM Opportunity 
            WHERE Id IN :oppIds
        ];

        List<TASKRAY__Project__c> projects = new List<TASKRAY__Project__c>();

        for (Opportunity o: opps) {
            TASKRAY__Project__c project = new TASKRAY__Project__c();
            project.Name = o.Name;
            if (String.isNotBlank(o.TaskRay_Parent__c)) {
                project.TASKRAY__Project_Parent__c = o.TaskRay_Parent__c;
            }
            project.TASKRAY__trStatus__c = '4bca81';
            project.TASKRAY__trAccount__c = o.AccountId;
            project.TASKRAY__trOpportunity__c = o.Id;
            projects.add(project);
        }

        insert projects;
        System.debug(projects);
        for (TASKRAY__Project__c p : projects) {
            oppToProject.put(p.TASKRAY__trOpportunity__c, p.Id);
        }

        List<TASKRAY__trTaskGroup__c> taskGroups = new List<TASKRAY__trTaskGroup__c>();
        Map<String, Id> taskGroupMap = new Map<String, Id>();

        for (Opportunity o: opps) {
            for (OpportunityLineItem oi : o.OpportunityLineItems) {
                if (String.isBlank(oi.Parent_Service_ID__c)) {
                    TASKRAY__trTaskGroup__c tG = new TASKRAY__trTaskGroup__c();
                    tG.TASKRAY__Project__c = oppToProject.get(o.Id);
                    tG.TASKRAY__trAccount__c = o.AccountId;
                    tG.TASKRAY__trOpportunity__c = o.Id;
                    tG.Name = oi.Service_Name_Text__c;
                    tG.TASKRAY__trStartDate__c = oi.Estimated_Start_Date__c;
                    tG.TASKRAY__trEndDate__c = oi.Estimated_End_Date__c;
                    tG.TASKRAY__trEstimatedHours__c = oi.Estimated_Hours_to_Complete__c;
                    
                    taskGroups.add(tG);
                }
            }
        }
        System.debug(taskGroups);
        insert taskGroups;

        for (TASKRAY__trTaskGroup__c t : taskGroups) {
            taskGroupMap.put(t.Name, t.Id);
        }
        System.debug(taskGroupMap);
        List<TASKRAY__Project_Task__c> projectTasks = new List<TASKRAY__Project_Task__c>();
 
        for (Opportunity o: opps) {
            for (OpportunityLineItem oi : o.OpportunityLineItems) {
                if (String.isNotBlank(oi.Parent_Service_ID__c)) {
                    TASKRAY__Project_Task__c projectTask = new TASKRAY__Project_Task__c();
                    projectTask.TASKRAY__Project__c = oppToProject.get(o.Id);
                    projectTask.Name = o.Name + ' ' + oi.Service_Name_Text__c;
                    String taskGroupName = o.Name + ' ' + oi.Product2.Parent_Service__r.Name;
                    if (taskGroupMap.containsKey(taskGroupName)) {
                        projectTask.TASKRAY__trTaskGroup__c = taskGroupMap.get(taskGroupName);
                    }
                    projectTask.TASKRAY__trAccount__c = o.AccountId;
                    projectTask.TASKRAY__trOpportunity__c = o.Id;
                    projectTask.TASKRAY__trStartDate__c = oi.Estimated_Start_Date__c;
                    projectTask.TASKRAY__Deadline__c = oi.Estimated_End_Date__c;
                    projectTask.TASKRAY__List__c = 'Holding';
                    projectTask.TASKRAY__Priority__c = 'Normal';
                    projectTask.TASKRAY__Description__c = oi.Description;
                    projectTask.TASKRAY__trEstimatedHours__c = oi.Estimated_Hours_to_Complete__c;
                    projectTasks.add(projectTask);
                }
            }
        }
        System.debug(projectTasks);
        insert projectTasks;

    }
}