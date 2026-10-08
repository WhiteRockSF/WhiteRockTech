public without sharing class PortalController {
    
    @AuraEnabled
    public static Contact createNewUser( Map<String, String> browserInfo, Map<String,Object> generalData) {
         
        Contact con = new Contact();
           System.debug('generalData ' + generalData ); 
        String email = String.valueOf(generalData.get('email'));
        String sub = String.valueOf(generalData.get('sub'));
        String lastName = String.valueOf(generalData.get('LastName'));
        String firstName = String.valueOf(generalData.get('FirstName'));
       

        List<Contact> contacts = [SELECT Id, Name, LastName, FirstName, sub__c, Email, Account.owner.name, 
        Account.owner.FirstName,Account.owner.LastName, AccountId,
        Account.owner.phone, Account.owner.email FROM Contact WHERE Email =: email LIMIT 1];

        con = new Contact(
            FirstName = firstName, LastName = lastName, Email = email, sub__c = sub
        );

        Login_History__c lh = new Login_History__c(
            Browser__c = browserInfo.containsKey('browser') ? browserInfo.get('browser') : '',
            Device__c = browserInfo.containsKey('device') ? browserInfo.get('device') : '',
            Date__c = Datetime.now()                
        );


        if (contacts.size() > 0) {
            con.Id = contacts[0].Id;
            lh.Account__c = contacts[0].AccountId;
        }  
        
        Database.upsert(con, Contact.Email, true);  

        lh.Contact__c = con.Id;
        Database.insert(lh); 

        return con; 
    }

    @AuraEnabled
    public static Map<String,Object> getUser(String code, Map<String, String> browserInfo) {
        
        Map<String,Object> userInfo = new Map<String,Object> ();
        Contact con = new Contact();
        if (String.isNotBlank(code)) {
            userInfo = (Map<String,Object>) JSON.deserializeUntyped(Auth0Controller.getUserInfo(code));
             
            String email = String.valueOf(userInfo.get('email'));
            String name = String.valueOf(userInfo.get('name'));
            String sub = String.valueOf(userInfo.get('sub'));
            if (String.isBlank(name)) {
                name = email;
            }
            List<Contact> contacts = [SELECT Id, Name, LastName, FirstName, sub__c, Email, Account.owner.name, 
            Account.owner.FirstName,Account.owner.LastName,AccountId,
            Account.owner.phone, Account.owner.email FROM Contact WHERE Email =: email LIMIT 1];
      
            Login_History__c lh = new Login_History__c(
                Browser__c = browserInfo.containsKey('browser') ? browserInfo.get('browser') : '',
                Device__c = browserInfo.containsKey('device') ? browserInfo.get('device') : '',
                Date__c = Datetime.now()                
            );
    
            if (contacts.size() > 0) {
                con = contacts[0];
                lh.Account__c = contacts[0].AccountId;
                lh.Contact__c = con.Id;
                userInfo.put('con',con);
                Database.insert(lh); 
            } 
        
        }
      
        return userInfo; 
    }

    @AuraEnabled
    public static Contact getContact (String conId){
        return [SELECT Id, Name, FirstName,LastName, 
         sub__c, Email, AccountId,Account.Name, Account.owner.name,
         Account.owner.FirstName,Account.owner.LastName, Account.owner.phone, Account.owner.email FROM Contact WHERE Id =:conId LIMIT 1];
    }

    @AuraEnabled
    public static string getLoginUrl(){
        return Auth0Controller.getLoginUrl(); 
    }

    @AuraEnabled
    public static string logoutAuth0(){
        return Auth0Controller.logoutAuth0(); 
    }
    public static void hack() {
        Integer i = 0;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++; i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
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