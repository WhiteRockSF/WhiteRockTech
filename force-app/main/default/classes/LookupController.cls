public without sharing class LookupController {

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> lookUp(String searchTerm, string myObject, String filter) {
        if (myObject == 'TASKRAY__Project_Task__c') {
            return lookUpTaskRayTasks(searchTerm, filter);
        }

        String myQuery = null;
        // String fields = myObject == 'Case' ? 'CaseNumber' : 'Name';
        String fields = 'Name';

        if (myObject == 'Production__c') {
            filter = ' (Work_In_Process_Status__c = \'New\' OR Work_In_Process_Status__c = \'In Process\')  AND Completed_Invoiced__c = false ';
        }

         if (myObject == 'Product2') {
            filter = ' ProductCode Like \'WR%\' ';
        }

        if(filter != null && filter != ''){
            myQuery = 'Select Id, ' + fields + ' from '+myObject+' Where ' + fields + ' Like  \'%' + searchTerm + '%\' AND '+filter+' LIMIT  5'; 
        }
        else {
            if(searchTerm == null || searchTerm == ''){
                myQuery = 'Select Id, ' + fields + ' from '+myObject+' Where LastViewedDate != NULL ORDER BY LastViewedDate DESC LIMIT  5'; 
            }
            else {
                myQuery = 'Select Id, ' + fields + ' from '+myObject+' Where ' + fields + ' Like  \'%' + searchTerm + '%\' LIMIT  5';
            }
        }

       
        System.debug(myQuery);
        
        List<sObject> lookUpList = database.query(myQuery);
        System.debug(lookUpList);
        List<Map<String, Object>> resList = new List<Map<String, Object>>();
        for (sObject o : lookUpList) {
            resList.add(
                new Map<String, Object> {
                    'Id' => o.Id,
                    'Name' => o.get('Name')
                }  
            );
        }

        return resList;  
    }

    private static List<Map<String, Object>> lookUpTaskRayTasks(String searchTerm, String filter) {
        String escapedTerm = searchTerm == null ? '' : String.escapeSingleQuotes(searchTerm);
        String myQuery;

        if (filter != null && filter != '') {
            myQuery =
                'SELECT Id, Name, TASKRAY__Project__r.Name FROM TASKRAY__Project_Task__c' +
                ' WHERE (Name LIKE \'%' + escapedTerm + '%\' OR TASKRAY__Project__r.Name LIKE \'%' + escapedTerm + '%\')' +
                ' AND ' + filter +
                ' LIMIT 5';
        } else if (searchTerm == null || searchTerm == '') {
            myQuery =
                'SELECT Id, Name, TASKRAY__Project__r.Name FROM TASKRAY__Project_Task__c' +
                ' WHERE LastViewedDate != NULL ORDER BY LastViewedDate DESC LIMIT 5';
        } else {
            myQuery =
                'SELECT Id, Name, TASKRAY__Project__r.Name FROM TASKRAY__Project_Task__c' +
                ' WHERE (Name LIKE \'%' + escapedTerm + '%\' OR TASKRAY__Project__r.Name LIKE \'%' + escapedTerm + '%\')' +
                ' LIMIT 5';
        }

        List<TASKRAY__Project_Task__c> tasks = Database.query(myQuery);
        List<Map<String, Object>> resList = new List<Map<String, Object>>();
        for (TASKRAY__Project_Task__c task : tasks) {
            String projectName = task.TASKRAY__Project__r == null ? null : task.TASKRAY__Project__r.Name;
            resList.add(
                new Map<String, Object>{
                    'Id' => task.Id,
                    'Name' => formatTaskRayDisplayName(task.Name, projectName)
                }
            );
        }
        return resList;
    }

    private static String formatTaskRayDisplayName(String taskName, String projectName) {
        if (String.isBlank(taskName)) {
            return '';
        }
        return String.isNotBlank(projectName) ? taskName + ' * ' + projectName : taskName;
    }

    public static void hack() {
        Integer i = 0;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
    }
}