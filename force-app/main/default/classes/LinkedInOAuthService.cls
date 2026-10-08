/**
 * LinkedIn OAuth token refresh (Marketing Developer Platform partners with refresh tokens).
 * POST https://www.linkedin.com/oauth/v2/accessToken
 */
public with sharing class LinkedInOAuthService {
    private static final String TOKEN_ENDPOINT = 'https://www.linkedin.com/oauth/v2/accessToken';

    public class RefreshResult {
        public Boolean success;
        public String message;
        public String accessToken;
    }

    /** Refresh if credentials exist and token is missing/expiring. Returns current (possibly refreshed) access token. */
    public static String ensureValidAccessToken() {
        LinkedInSecretStore.TokenBundle bundle = LinkedInSecretStore.getTokenBundle();
        if (String.isNotBlank(bundle.accessToken) && !LinkedInSecretStore.isAccessTokenExpiringSoon()) {
            return bundle.accessToken.trim();
        }
        if (!LinkedInSecretStore.hasRefreshCredentials()) {
            return String.isNotBlank(bundle.accessToken) ? bundle.accessToken.trim() : null;
        }
        RefreshResult refreshed = refreshAccessToken();
        if (refreshed.success && String.isNotBlank(refreshed.accessToken)) {
            return refreshed.accessToken;
        }
        // Fall back to existing token if refresh failed but we still have one
        if (String.isNotBlank(bundle.accessToken)) {
            return bundle.accessToken.trim();
        }
        throw new LinkedInIntegrationConfig.LinkedInAdMetricsException(
            'LinkedIn token refresh failed: ' + refreshed.message
        );
    }

    public static RefreshResult refreshAccessToken() {
        RefreshResult out = new RefreshResult();
        LinkedInSecretStore.TokenBundle bundle = LinkedInSecretStore.getTokenBundle();
        if (!LinkedInSecretStore.hasRefreshCredentials()) {
            out.success = false;
            out.message = 'Refresh Token, Client Id, and Client Secret are required.';
            return out;
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint(TOKEN_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setTimeout(60000);
        req.setBody(
            'grant_type=refresh_token'
            + '&refresh_token=' + EncodingUtil.urlEncode(bundle.refreshToken.trim(), 'UTF-8')
            + '&client_id=' + EncodingUtil.urlEncode(bundle.clientId.trim(), 'UTF-8')
            + '&client_secret=' + EncodingUtil.urlEncode(bundle.clientSecret.trim(), 'UTF-8')
        );

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            out.success = false;
            out.message = 'HTTP ' + res.getStatusCode() + ': ' + truncate(res.getBody(), 400);
            return out;
        }

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        String accessToken = (String) parsed.get('access_token');
        if (String.isBlank(accessToken)) {
            out.success = false;
            out.message = 'No access_token in refresh response.';
            return out;
        }

        String newRefresh = (String) parsed.get('refresh_token');
        Datetime expiresAt = null;
        Object expiresInObj = parsed.get('expires_in');
        if (expiresInObj != null) {
            Integer expiresIn = Integer.valueOf(String.valueOf(expiresInObj));
            expiresAt = System.now().addSeconds(expiresIn);
        }

        LinkedInSecretStore.saveTokens(
            accessToken,
            String.isNotBlank(newRefresh) ? newRefresh : null,
            null,
            null,
            expiresAt
        );

        out.success = true;
        out.accessToken = accessToken;
        out.message = 'Access token refreshed'
            + (expiresAt != null ? ' (expires ' + expiresAt.format() + ')' : '')
            + '.';
        return out;
    }

    public static String testRefresh() {
        if (!LinkedInSecretStore.hasRefreshCredentials()) {
            return 'ERROR: Set Refresh Token, Client Id, and Client Secret, then Save Settings.';
        }
        try {
            RefreshResult result = refreshAccessToken();
            return result.success ? 'SUCCESS: ' + result.message : 'ERROR: ' + result.message;
        } catch (Exception e) {
            return 'ERROR: ' + e.getMessage();
        }
    }

    private static String truncate(String value, Integer maxLen) {
        if (String.isBlank(value) || value.length() <= maxLen) {
            return value;
        }
        return value.substring(0, maxLen) + '...';
    }
}