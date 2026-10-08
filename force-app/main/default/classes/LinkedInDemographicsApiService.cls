public with sharing class LinkedInDemographicsApiService {
    public class FetchRequest {
        public String campaignName;
        public String campaignId;
        public Date startDate;
        public Date endDate;
    }

    public class FetchResult {
        @AuraEnabled public Integer rowCount = 0;
        @AuraEnabled public Integer inserted = 0;
        @AuraEnabled public Integer updated = 0;
        @AuraEnabled public Integer namesResolved = 0;
        @AuraEnabled public String message;
    }

    public static FetchResult fetchAndStore(FetchRequest req) {
        LinkedIn_Integration_Settings__c settings = LinkedInIntegrationConfig.getOrgSettings();
        assertLinkedInAuthConfigured(settings);
        if (String.isBlank(settings.LinkedIn_Ad_Account_Urn__c)) {
            throw new LinkedInIntegrationConfig.LinkedInAdMetricsException('LinkedIn Ad Account URN is not configured.');
        }

        String campaignId = String.isNotBlank(req.campaignId)
            ? req.campaignId.trim()
            : settings.Default_LinkedIn_Campaign_Id__c;
        if (String.isBlank(campaignId)) {
            throw new LinkedInIntegrationConfig.LinkedInAdMetricsException('LinkedIn Campaign Id is required for API fetch.');
        }
        if (String.isBlank(req.campaignName)) {
            throw new LinkedInIntegrationConfig.LinkedInAdMetricsException('Campaign Name is required.');
        }

        Date startDate = req.startDate != null ? req.startDate : Date.today().addDays(-30);
        Date endDate = req.endDate != null ? req.endDate : Date.today();
        if (endDate < startDate) {
            endDate = startDate;
        }

        String path = buildAnalyticsPath(settings, campaignId, startDate, endDate);
        HttpResponse res = sendGet(path, settings);

        if (res.getStatusCode() != 200) {
            throw new LinkedInIntegrationConfig.LinkedInAdMetricsException(
                'LinkedIn API error ' + res.getStatusCode() + ': ' + res.getBody()
            );
        }

        List<LinkedInDemographicsCsvParser.DemographicsRow> rows = parseAnalyticsResponse(res.getBody());
        NameResolveResult names = enrichCompanyNames(rows, settings);
        LinkedInAdMetricRepository.UpsertResult repoResult = LinkedInAdMetricRepository.upsertMetrics(
            req.campaignName.trim(),
            campaignId,
            'LinkedIn API',
            startDate,
            endDate,
            rows
        );

        FetchResult out = new FetchResult();
        out.rowCount = rows.size();
        out.inserted = repoResult.inserted;
        out.updated = repoResult.updated;
        out.namesResolved = names.resolved;
        if (rows.isEmpty()) {
            out.message =
                'LinkedIn API OK (200), but 0 company rows for campaign '
                + campaignId
                + ' ('
                + String.valueOf(startDate)
                + ' – '
                + String.valueOf(endDate)
                + '). Check Campaign Id / date range.';
        } else {
            out.message =
                'Received '
                + rows.size()
                + ' rows (inserted '
                + repoResult.inserted
                + ', updated '
                + repoResult.updated
                + '). Company names resolved: '
                + names.resolved
                + '/'
                + names.attempted
                + '.';
            if (String.isNotBlank(names.errorDetail)) {
                out.message += ' Name lookup: ' + names.errorDetail;
            }
        }
        return out;
    }

    private static String buildAnalyticsPath(
        LinkedIn_Integration_Settings__c settings,
        String campaignId,
        Date startDate,
        Date endDate
    ) {
        String accountUrn = EncodingUtil.urlEncode(settings.LinkedIn_Ad_Account_Urn__c, 'UTF-8');
        String campaignUrn = EncodingUtil.urlEncode('urn:li:sponsoredCampaign:' + campaignId, 'UTF-8');
        String dateRange =
            '(start:(year:' +
            startDate.year() +
            ',month:' +
            startDate.month() +
            ',day:' +
            startDate.day() +
            '),end:(year:' +
            endDate.year() +
            ',month:' +
            endDate.month() +
            ',day:' +
            endDate.day() +
            '))';

        return '/rest/adAnalytics?q=analytics'
            + '&pivot=MEMBER_COMPANY'
            + '&dateRange=' + dateRange
            + '&timeGranularity=ALL'
            + '&accounts=List(' + accountUrn + ')'
            + '&campaigns=List(' + campaignUrn + ')'
            + '&fields=impressions,clicks,externalWebsiteConversions,pivotValues';
    }

    private static HttpResponse sendGet(String path, LinkedIn_Integration_Settings__c settings) {
        String token = LinkedInIntegrationConfig.getLinkedInAccessToken(settings);
        if (String.isBlank(token)) {
            throw new LinkedInIntegrationConfig.LinkedInAdMetricsException('LinkedIn Access Token is not configured.');
        }

        HttpResponse res = doGet(path, settings, token);
        if (res.getStatusCode() == 401 && LinkedInSecretStore.hasRefreshCredentials()) {
            LinkedInOAuthService.RefreshResult refreshed = LinkedInOAuthService.refreshAccessToken();
            if (refreshed.success && String.isNotBlank(refreshed.accessToken)) {
                res = doGet(path, settings, refreshed.accessToken);
            }
        }
        return res;
    }

    private static HttpResponse doGet(String path, LinkedIn_Integration_Settings__c settings, String token) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.linkedin.com' + path);
        req.setHeader('Authorization', 'Bearer ' + token.trim());
        req.setMethod('GET');
        req.setTimeout(120000);
        req.setHeader('Linkedin-Version', String.isNotBlank(settings.LinkedIn_API_Version__c) ? settings.LinkedIn_API_Version__c : '202607');
        req.setHeader('X-Restli-Protocol-Version', '2.0.0');
        return new Http().send(req);
    }

    private static List<LinkedInDemographicsCsvParser.DemographicsRow> parseAnalyticsResponse(String body) {
        List<LinkedInDemographicsCsvParser.DemographicsRow> rows = new List<LinkedInDemographicsCsvParser.DemographicsRow>();
        Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(body);
        List<Object> elements = (List<Object>) root.get('elements');
        if (elements == null) {
            return rows;
        }

        for (Object elObj : elements) {
            Map<String, Object> el = (Map<String, Object>) elObj;
            LinkedInDemographicsCsvParser.DemographicsRow row = new LinkedInDemographicsCsvParser.DemographicsRow();
            row.impressions = toDecimal(el.get('impressions'));
            row.clicks = toDecimal(el.get('clicks'));
            row.conversions = toDecimal(el.get('externalWebsiteConversions'));
            CompanyRef ref = resolveCompanyRef(el);
            row.organizationId = ref.organizationId;
            row.companyName = ref.displayName;
            if (String.isNotBlank(row.companyName) || String.isNotBlank(row.organizationId)) {
                if (String.isBlank(row.companyName)) {
                    row.companyName = row.organizationId;
                }
                rows.add(row);
            }
        }
        return rows;
    }

    private class CompanyRef {
        String organizationId;
        String displayName;
    }

    private static CompanyRef resolveCompanyRef(Map<String, Object> el) {
        CompanyRef ref = new CompanyRef();
        if (el.containsKey('pivotValue~')) {
            Map<String, Object> pivot = (Map<String, Object>) el.get('pivotValue~');
            if (pivot != null) {
                if (pivot.containsKey('localizedName')) {
                    ref.displayName = String.valueOf(pivot.get('localizedName'));
                } else if (pivot.containsKey('name')) {
                    Object nameObj = pivot.get('name');
                    if (nameObj instanceof Map<String, Object>) {
                        Map<String, Object> nameMap = (Map<String, Object>) nameObj;
                        if (nameMap.containsKey('localized')) {
                            Map<String, Object> localized = (Map<String, Object>) nameMap.get('localized');
                            if (localized != null && !localized.isEmpty()) {
                                ref.displayName = String.valueOf(localized.values().iterator().next());
                            }
                        }
                    } else if (nameObj != null) {
                        ref.displayName = String.valueOf(nameObj);
                    }
                }
                if (pivot.containsKey('id')) {
                    ref.organizationId = String.valueOf(pivot.get('id'));
                }
            }
        }
        List<Object> pivots = (List<Object>) el.get('pivotValues');
        if (pivots != null && !pivots.isEmpty()) {
            String urn = String.valueOf(pivots[0]);
            String idFromUrn = extractOrganizationId(urn);
            if (String.isNotBlank(idFromUrn)) {
                ref.organizationId = idFromUrn;
            }
            if (String.isBlank(ref.displayName) && String.isBlank(ref.organizationId)) {
                ref.displayName = urn;
            }
        }
        return ref;
    }

    private static String extractOrganizationId(String urnOrId) {
        if (String.isBlank(urnOrId)) {
            return null;
        }
        String v = urnOrId.trim();
        if (v.contains(':')) {
            v = v.substring(v.lastIndexOf(':') + 1);
        }
        return String.isNotBlank(v) ? v : null;
    }

    private class NameResolveResult {
        Integer attempted = 0;
        Integer resolved = 0;
        String errorDetail;
    }

    /**
     * LinkedIn adAnalytics often returns only organization URNs. Resolve localizedName via organizationsLookup.
     */
    private static NameResolveResult enrichCompanyNames(
        List<LinkedInDemographicsCsvParser.DemographicsRow> rows,
        LinkedIn_Integration_Settings__c settings
    ) {
        NameResolveResult result = new NameResolveResult();
        if (rows == null || rows.isEmpty()) {
            return result;
        }
        Set<String> idsToResolve = new Set<String>();
        for (LinkedInDemographicsCsvParser.DemographicsRow row : rows) {
            if (String.isNotBlank(row.organizationId) && looksLikeNumericId(row.companyName)) {
                idsToResolve.add(row.organizationId);
            } else if (String.isNotBlank(row.organizationId) && String.isBlank(row.companyName)) {
                idsToResolve.add(row.organizationId);
            } else if (looksLikeNumericId(row.companyName)) {
                row.organizationId = row.companyName;
                idsToResolve.add(row.companyName);
            }
        }
        result.attempted = idsToResolve.size();
        if (idsToResolve.isEmpty()) {
            return result;
        }

        LookupBundle bundle = lookupOrganizationNames(new List<String>(idsToResolve), settings);
        result.errorDetail = bundle.errorDetail;
        for (LinkedInDemographicsCsvParser.DemographicsRow row : rows) {
            String id = String.isNotBlank(row.organizationId) ? row.organizationId : row.companyName;
            if (String.isNotBlank(id) && bundle.idToName.containsKey(id)) {
                row.companyName = bundle.idToName.get(id);
                result.resolved++;
            }
        }
        System.debug(
            LoggingLevel.INFO,
            '[LinkedInDemographicsApiService] Resolved ' + result.resolved + '/' + result.attempted
            + ' company names. ' + (result.errorDetail != null ? result.errorDetail : '')
        );
        return result;
    }

    private static Boolean looksLikeNumericId(String value) {
        if (String.isBlank(value)) {
            return false;
        }
        String v = value.trim();
        if (v.length() > 20) {
            return false;
        }
        return Pattern.matches('^[0-9]+$', v);
    }

    private class LookupBundle {
        Map<String, String> idToName = new Map<String, String>();
        String errorDetail;
    }

    private static LookupBundle lookupOrganizationNames(
        List<String> organizationIds,
        LinkedIn_Integration_Settings__c settings
    ) {
        LookupBundle bundle = new LookupBundle();
        if (organizationIds == null || organizationIds.isEmpty()) {
            return bundle;
        }
        Integer batchSize = 20;
        List<String> errors = new List<String>();
        for (Integer i = 0; i < organizationIds.size(); i += batchSize) {
            Integer endIdx = Math.min(i + batchSize, organizationIds.size());
            List<String> chunk = new List<String>();
            for (Integer j = i; j < endIdx; j++) {
                chunk.add(organizationIds[j]);
            }
            LookupBundle chunkResult = lookupOrganizationNamesChunk(chunk, settings);
            bundle.idToName.putAll(chunkResult.idToName);
            if (String.isNotBlank(chunkResult.errorDetail)) {
                errors.add(chunkResult.errorDetail);
            }
        }
        // If batch returned nothing, try one-by-one (some tokens reject List() encoding)
        if (bundle.idToName.isEmpty() && !organizationIds.isEmpty()) {
            Integer soloLimit = Math.min(organizationIds.size(), 40);
            for (Integer i = 0; i < soloLimit; i++) {
                LookupBundle one = lookupSingleOrganization(organizationIds[i], settings);
                bundle.idToName.putAll(one.idToName);
                if (String.isNotBlank(one.errorDetail) && errors.size() < 3) {
                    errors.add(one.errorDetail);
                }
            }
        }
        if (!errors.isEmpty() && bundle.idToName.isEmpty()) {
            bundle.errorDetail = errors[0];
        } else if (!errors.isEmpty() && bundle.idToName.size() < organizationIds.size()) {
            bundle.errorDetail = 'partial: ' + errors[0];
        }
        return bundle;
    }

    private static LookupBundle lookupOrganizationNamesChunk(
        List<String> organizationIds,
        LinkedIn_Integration_Settings__c settings
    ) {
        LookupBundle bundle = new LookupBundle();
        // Rest.li List(): use raw commas. Pre-encoding as %2C gets double-encoded by HttpRequest
        // and LinkedIn then treats the whole string as one batch key → NumberFormatException.
        String path = '/rest/organizationsLookup?ids=List(' + String.join(organizationIds, ',') + ')';
        HttpResponse res = sendGet(path, settings);
        if (res.getStatusCode() != 200) {
            // Fallback: URN form List(urn:li:organization:123,urn:li:organization:456)
            List<String> urns = new List<String>();
            for (String id : organizationIds) {
                urns.add('urn:li:organization:' + id);
            }
            String urnPath = '/rest/organizationsLookup?ids=List(' + String.join(urns, ',') + ')';
            HttpResponse alt = sendGet(urnPath, settings);
            if (alt.getStatusCode() == 200) {
                parseLookupResults(alt.getBody(), bundle.idToName);
                return bundle;
            }
            bundle.errorDetail =
                'organizationsLookup HTTP '
                + res.getStatusCode()
                + ': '
                + truncateBody(res.getBody(), 220);
            return bundle;
        }
        parseLookupResults(res.getBody(), bundle.idToName);
        if (bundle.idToName.isEmpty()) {
            bundle.errorDetail = 'organizationsLookup 200 but no names in results: ' + truncateBody(res.getBody(), 220);
        }
        return bundle;
    }

    private static LookupBundle lookupSingleOrganization(String organizationId, LinkedIn_Integration_Settings__c settings) {
        LookupBundle bundle = new LookupBundle();
        if (String.isBlank(organizationId)) {
            return bundle;
        }
        // Single id must also use List(...) — bare ?ids=123 → "Invalid query parameters"
        String path = '/rest/organizationsLookup?ids=List(' + organizationId.trim() + ')';
        HttpResponse res = sendGet(path, settings);
        if (res.getStatusCode() != 200) {
            String urnPath =
                '/rest/organizationsLookup?ids=List(urn:li:organization:' + organizationId.trim() + ')';
            HttpResponse alt = sendGet(urnPath, settings);
            if (alt.getStatusCode() == 200) {
                parseLookupResults(alt.getBody(), bundle.idToName);
                return bundle;
            }
            bundle.errorDetail =
                'org ' + organizationId + ' HTTP ' + res.getStatusCode() + ': ' + truncateBody(res.getBody(), 160);
            return bundle;
        }
        parseLookupResults(res.getBody(), bundle.idToName);
        return bundle;
    }

    private static void parseLookupResults(String body, Map<String, String> out) {
        if (String.isBlank(body) || out == null) {
            return;
        }
        Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(body);
        Map<String, Object> results = (Map<String, Object>) root.get('results');
        if (results == null) {
            // Some responses return the org object directly for single id
            if (root.containsKey('localizedName') || root.containsKey('id')) {
                String name = extractOrgName(root);
                if (String.isNotBlank(name) && root.containsKey('id')) {
                    out.put(String.valueOf(root.get('id')), name);
                }
            }
            return;
        }
        for (String key : results.keySet()) {
            Map<String, Object> org = (Map<String, Object>) results.get(key);
            if (org == null) {
                continue;
            }
            String name = extractOrgName(org);
            if (String.isNotBlank(name)) {
                out.put(key, name);
                if (org.containsKey('id')) {
                    out.put(String.valueOf(org.get('id')), name);
                }
            }
        }
    }

    private static String extractOrgName(Map<String, Object> org) {
        if (org == null) {
            return null;
        }
        if (org.containsKey('localizedName') && org.get('localizedName') != null) {
            return String.valueOf(org.get('localizedName'));
        }
        if (org.containsKey('name')) {
            Object nameObj = org.get('name');
            if (nameObj instanceof Map<String, Object>) {
                Map<String, Object> nameMap = (Map<String, Object>) nameObj;
                Map<String, Object> localized = (Map<String, Object>) nameMap.get('localized');
                if (localized != null && !localized.isEmpty()) {
                    return String.valueOf(localized.values().iterator().next());
                }
            } else if (nameObj != null) {
                return String.valueOf(nameObj);
            }
        }
        if (org.containsKey('vanityName') && org.get('vanityName') != null) {
            return String.valueOf(org.get('vanityName'));
        }
        return null;
    }

    private static String truncateBody(String value, Integer maxLen) {
        if (String.isBlank(value) || value.length() <= maxLen) {
            return value;
        }
        return value.substring(0, maxLen) + '...';
    }

    private static Decimal toDecimal(Object val) {
        if (val == null) {
            return 0;
        }
        return Decimal.valueOf(String.valueOf(val));
    }

    private static void assertLinkedInAuthConfigured(LinkedIn_Integration_Settings__c settings) {
        if (String.isBlank(LinkedInIntegrationConfig.getLinkedInAccessToken(settings))) {
            throw new LinkedInIntegrationConfig.LinkedInAdMetricsException(
                'LinkedIn Access Token is not configured. Paste token in API Settings and Save (enable Use LinkedIn Named Credential for long tokens).'
            );
        }
    }

    public static String testConnection() {
        LinkedIn_Integration_Settings__c settings = LinkedInIntegrationConfig.getOrgSettings();
        Boolean useSecureStore = settings.Use_LinkedIn_Named_Credential__c == true;
        if (String.isBlank(LinkedInIntegrationConfig.getLinkedInAccessToken(settings))) {
            return 'ERROR: LinkedIn token not set. Paste token in API Settings, enable Use LinkedIn Named Credential for long tokens, and Save.';
        }
        try {
            HttpResponse res = sendGet(
                '/rest/adAccounts?q=search&search=(status:(values:List(ACTIVE)))&count=1',
                settings
            );
            if (res.getStatusCode() == 200) {
                return 'SUCCESS: LinkedIn API reachable' + (useSecureStore ? ' (secure token store).' : '.');
            }
            String body = res.getBody();
            if (String.isNotBlank(body) && body.length() > 300) {
                body = body.substring(0, 300) + '...';
            }
            return 'ERROR ' + res.getStatusCode() + ': ' + (String.isBlank(body) ? '(empty body)' : body);
        } catch (Exception e) {
            return 'ERROR: ' + e.getMessage();
        }
    }
}