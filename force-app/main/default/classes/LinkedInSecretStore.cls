public with sharing class LinkedInSecretStore {
    private static final String CONFIG_KEY = 'DEFAULT';
    /** Refresh access token this many hours before expiry. */
    private static final Integer REFRESH_BUFFER_HOURS = 24;
    /** If LinkedIn does not return expires_in, assume ~55 days (tokens are typically 60 days). */
    private static final Integer DEFAULT_ACCESS_TOKEN_DAYS = 55;

    public class TokenBundle {
        public String accessToken;
        public String refreshToken;
        public String clientId;
        public String clientSecret;
        public Datetime accessTokenExpiresAt;
    }

    public static void saveAccessToken(String accessToken) {
        saveTokens(accessToken, null, null, null, null);
    }

    public static void saveTokens(
        String accessToken,
        String refreshToken,
        String clientId,
        String clientSecret,
        Datetime accessTokenExpiresAt
    ) {
        LinkedIn_Api_Secret__c rec = getOrCreateRecord();
        Boolean changed = false;

        if (String.isNotBlank(accessToken)) {
            String token = accessToken.trim();
            if (token.startsWithIgnoreCase('Bearer ')) {
                token = token.substring(7).trim();
            }
            rec.Access_Token__c = token;
            changed = true;
            if (accessTokenExpiresAt != null) {
                rec.Access_Token_Expires_At__c = accessTokenExpiresAt;
            } else if (rec.Access_Token_Expires_At__c == null) {
                rec.Access_Token_Expires_At__c = System.now().addDays(DEFAULT_ACCESS_TOKEN_DAYS);
            }
        }
        if (String.isNotBlank(refreshToken)) {
            rec.Refresh_Token__c = refreshToken.trim();
            changed = true;
        }
        if (String.isNotBlank(clientId)) {
            rec.Client_Id__c = clientId.trim();
            changed = true;
        }
        if (String.isNotBlank(clientSecret)) {
            rec.Client_Secret__c = clientSecret.trim();
            changed = true;
        }
        if (changed) {
            upsert rec;
        }
    }

    public static TokenBundle getTokenBundle() {
        List<LinkedIn_Api_Secret__c> rows = [
            SELECT
                Access_Token__c,
                Refresh_Token__c,
                Client_Id__c,
                Client_Secret__c,
                Access_Token_Expires_At__c
            FROM LinkedIn_Api_Secret__c
            WHERE Config_Key__c = :CONFIG_KEY
            LIMIT 1
        ];
        TokenBundle bundle = new TokenBundle();
        if (rows.isEmpty()) {
            return bundle;
        }
        LinkedIn_Api_Secret__c rec = rows[0];
        bundle.accessToken = rec.Access_Token__c;
        bundle.refreshToken = rec.Refresh_Token__c;
        bundle.clientId = rec.Client_Id__c;
        bundle.clientSecret = rec.Client_Secret__c;
        bundle.accessTokenExpiresAt = rec.Access_Token_Expires_At__c;
        return bundle;
    }

    public static String getAccessToken() {
        return getTokenBundle().accessToken;
    }

    public static Boolean hasAccessToken() {
        return String.isNotBlank(getAccessToken());
    }

    public static Boolean hasRefreshCredentials() {
        TokenBundle b = getTokenBundle();
        return String.isNotBlank(b.refreshToken)
            && String.isNotBlank(b.clientId)
            && String.isNotBlank(b.clientSecret);
    }

    public static Boolean isAccessTokenExpiringSoon() {
        TokenBundle b = getTokenBundle();
        if (b.accessTokenExpiresAt == null) {
            return hasRefreshCredentials();
        }
        return b.accessTokenExpiresAt <= System.now().addHours(REFRESH_BUFFER_HOURS);
    }

    public static Boolean hasRefreshTokenConfigured() {
        return String.isNotBlank(getTokenBundle().refreshToken);
    }

    public static Boolean hasClientCredentialsConfigured() {
        TokenBundle b = getTokenBundle();
        return String.isNotBlank(b.clientId) && String.isNotBlank(b.clientSecret);
    }

    private static LinkedIn_Api_Secret__c getOrCreateRecord() {
        List<LinkedIn_Api_Secret__c> existing = [
            SELECT
                Id,
                Access_Token__c,
                Refresh_Token__c,
                Client_Id__c,
                Client_Secret__c,
                Access_Token_Expires_At__c
            FROM LinkedIn_Api_Secret__c
            WHERE Config_Key__c = :CONFIG_KEY
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0];
        }
        return new LinkedIn_Api_Secret__c(Config_Key__c = CONFIG_KEY, Name = 'Default');
    }
}