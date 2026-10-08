// Запустите в Developer Console → Debug → Open Execute Anonymous Window

System.debug('=== Testing HubSpot Companies API ===');

try {
    List<BuyerIntentController.CompanyIntent> companies = BuyerIntentController.getCompanyIntents();
    
    System.debug('Total Companies: ' + companies.size());
    
    if (companies.size() > 0) {
        System.debug('\n=== First 5 Companies ===');
        Integer count = Math.min(5, companies.size());
        for (Integer i = 0; i < count; i++) {
            BuyerIntentController.CompanyIntent c = companies[i];
            System.debug((i+1) + '. ' + c.companyName);
            System.debug('   Industry: ' + c.industry);
            System.debug('   Country: ' + c.country);
            System.debug('   Employees: ' + c.employeeRange);
            System.debug('   Page Views: ' + c.pageViews);
            System.debug('   Unique Visitors: ' + c.uniqueVisitors);
            System.debug('   URL: ' + c.companyUrl);
            System.debug('---');
        }
    }
} catch (Exception e) {
    System.debug('ERROR: ' + e.getMessage());
    System.debug('Stack: ' + e.getStackTraceString());
}

System.debug('=== Test Complete ===');
