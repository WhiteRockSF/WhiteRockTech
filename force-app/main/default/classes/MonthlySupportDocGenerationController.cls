public class MonthlySupportDocGenerationController {
    public List<TASKRAY__trChecklistGroup__c> checklists {get; set;}
    public String monthValue {get; set;}
    public String companyName {get; set;}
    private String taskId;

	public MonthlySupportDocGenerationController(ApexPages.StandardController stdController) {

        // Get record ID from page parameters
        taskId = stdController.getId();

        if(taskId == null) return;

        DateTime dt = DateTime.now();
        monthValue = dt.format('MMMM');

        checklists = [SELECT Id, Name, TASKRAY__TaskForGroup__r.Account_Name__c,  (SELECT Id, Name, TASKRAY__trLongName__c FROM TASKRAY__TaskRay_Checklist_Items__r)
                        FROM TASKRAY__trChecklistGroup__c WHERE TASKRAY__TaskForGroup__c = :taskId];

        companyName = (checklists.size() > 0 && checklists.get(0).TASKRAY__TaskForGroup__r.Account_Name__c != null) 
            ? checklists.get(0).TASKRAY__TaskForGroup__r.Account_Name__c
            : 'Customer';
    }

    // This method generates the file and links it to the record
    public PageReference saveToRecord() {

        PageReference docPage = Page.MonthlySupportDocTemplate; 
        docPage.getParameters().put('id', this.taskId);        
        
        Blob docBlob;
        if (System.Test.isRunningTest()) {
            docBlob = Blob.valueOf('Test Content');
        } else {
            docBlob = docPage.getContent();
        }
        
        String fileName = this.monthValue + 'MonthlyReport_' + this.companyName + '.doc';
        
        ContentVersion fileVersion = new ContentVersion();
        fileVersion.Title = fileName;
        fileVersion.PathOnClient = fileName;
        fileVersion.VersionData = docBlob;
        fileVersion.FirstPublishLocationId = this.taskId;
        
        insert fileVersion;
        
        PageReference returnPage = new PageReference('/' + this.taskId);
        returnPage.setRedirect(true);
        return returnPage;
    }
}