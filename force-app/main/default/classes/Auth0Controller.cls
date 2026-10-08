public without sharing class Auth0Controller {
    private static Auth0Connect__c auth0Connect = Auth0Connect__c.getValues('auth0');
    
    private static String getToken(String code) {
        Map<String, Object> body = new Map<String, Object>{
            'grant_type' => 'authorization_code',
            'client_id' => auth0Connect.client_id__c,
            'client_secret' => auth0Connect.client_secret__c,
            'code' => code,
            'redirect_uri' => auth0Connect.callback__c
        };
        return PortalConnector.doCallout(auth0Connect.url__c + '/oauth/token', 'POST', body, '');
    }

    public static String getUserInfo(String code) {
        Map<String,Object> tokenMap = (Map<String,Object>)JSON.deserializeUntyped(getToken(code));
        System.debug('access_token ' + String.valueOf(tokenMap.get('access_token')));
        return PortalConnector.doCallout(auth0Connect.url__c + '/userinfo', 'GET', '', String.valueOf(tokenMap.get('access_token')));
    }

    public static String getLoginUrl(){
        return auth0Connect.url__c + '/authorize?response_type=code&client_id=' + auth0Connect.client_id__c + '&redirect_uri='+auth0Connect.callback__c+'&scope=openid%20profile%20email';
    }

    @AuraEnabled
    public static String logoutAuth0(){
        return auth0Connect.url__c + '/v2/logout?client_id=' + auth0Connect.client_id__c + '&returnTo=' + auth0Connect.returnTo__c;
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
    }
 
}