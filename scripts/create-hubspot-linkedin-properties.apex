LinkedIn_Integration_Settings__c settings = LinkedInIntegrationConfig.getOrgSettings();
Boolean useNc = settings.Use_HubSpot_Named_Credential__c == true;
if (!useNc && String.isBlank(settings.HubSpot_Access_Token__c)) {
    System.debug('ERROR: HubSpot token not configured');
    return;
}

List<Map<String, Object>> props = new List<Map<String, Object>>{
    new Map<String, Object>{
        'name' => 'linkedin_impressions',
        'label' => 'LinkedIn Impressions',
        'type' => 'number',
        'fieldType' => 'number',
        'groupName' => 'companyinformation',
        'description' => 'LinkedIn ad impressions by company (synced from Salesforce)'
    },
    new Map<String, Object>{
        'name' => 'linkedin_clicks',
        'label' => 'LinkedIn Clicks',
        'type' => 'number',
        'fieldType' => 'number',
        'groupName' => 'companyinformation',
        'description' => 'LinkedIn ad clicks by company (synced from Salesforce)'
    },
    new Map<String, Object>{
        'name' => 'linkedin_conversions',
        'label' => 'LinkedIn Conversions',
        'type' => 'number',
        'fieldType' => 'number',
        'groupName' => 'companyinformation',
        'description' => 'LinkedIn ad conversions by company (synced from Salesforce)'
    },
    new Map<String, Object>{
        'name' => 'linkedin_campaign_name',
        'label' => 'LinkedIn Campaign Name',
        'type' => 'string',
        'fieldType' => 'text',
        'groupName' => 'companyinformation',
        'description' => 'LinkedIn campaign name for last synced metrics'
    }
};

for (Map<String, Object> prop : props) {
    HttpRequest req = new HttpRequest();
    if (useNc) {
        req.setEndpoint('callout:HubSpot/crm/v3/properties/companies');
    } else {
        req.setEndpoint('https://api.hubapi.com/crm/v3/properties/companies');
        req.setHeader('Authorization', 'Bearer ' + settings.HubSpot_Access_Token__c.trim());
    }
    req.setMethod('POST');
    req.setHeader('Content-Type', 'application/json');
    req.setTimeout(60000);
    req.setBody(JSON.serialize(prop));
    HttpResponse res = new Http().send(req);
    String name = String.valueOf(prop.get('name'));
    if (res.getStatusCode() == 201 || res.getStatusCode() == 200) {
        System.debug('CREATED ' + name);
    } else if (res.getStatusCode() == 409 || (res.getBody() != null && res.getBody().contains('already exists'))) {
        System.debug('EXISTS ' + name);
    } else {
        String body = res.getBody();
        if (body != null && body.length() > 400) {
            body = body.substring(0, 400);
        }
        System.debug('ERROR ' + name + ' HTTP ' + res.getStatusCode() + ' ' + body);
    }
}
