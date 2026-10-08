public class LoginHistoriesController {
 
    public Contact contact {get; set;}
    public Datetime lastLoginDate {get; set;}
    public Integer totalLogin {get; set;}
    public Integer totalLogin30 {get; set;}
    public Datetime lastOrderDate {get; set;}
    public Integer totalOrders {get; set;}
    public Integer totalOrders30 {get; set;}


    public LoginHistoriesController(ApexPages.StandardController stdController) {
        contact = (Contact)stdController.getRecord();
        System.debug('contact ' + contact);
        totalLogin = 0;
        totalLogin30 = 0;
        totalOrders = 0;
        totalOrders30 = 0;
        List<Contact> contacts = [SELECT Id, AccountId FROM Contact WHERE Id = :contact.Id];
        List<Login_History__c> loginHistories = [
            SELECT Id, Name, CreatedDate, Contact__c FROM Login_History__c 
            WHERE Contact__c = : contacts[0].Id AND CreatedDate = LAST_N_DAYS:30 ORDER BY CreatedDate DESC
        ];

        totalLogin = [
            SELECT COUNT() FROM Login_History__c WHERE Contact__c = :contacts[0].Id ];

        totalLogin30 = loginHistories.size();
        if (totalLogin30 > 0) {
            lastLoginDate = loginHistories[0].CreatedDate;
        } 
        
        if (String.isNotBlank(contacts[0].AccountId)) {
            List<Order> orders = [
                SELECT Id, Name, CreatedDate, AccountId FROM Order 
                WHERE AccountId = : contacts[0].AccountId AND CreatedDate = LAST_N_DAYS:30 ORDER BY CreatedDate DESC
            ];
    
            totalOrders = [
                SELECT COUNT() FROM Order 
                WHERE AccountId = : contacts[0].AccountId 
            ];
            totalOrders30 = orders.size();
            if (totalOrders30 > 0) {
                lastOrderDate = orders[0].CreatedDate;
            } 
        }
        

    }
     
}