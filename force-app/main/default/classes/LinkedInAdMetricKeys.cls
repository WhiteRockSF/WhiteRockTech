public with sharing class LinkedInAdMetricKeys {
    public static String buildSyncKey(String campaignName, String companyName) {
        String c = normalizePart(campaignName);
        String co = normalizePart(companyName);
        if (String.isBlank(c) || String.isBlank(co)) {
            return null;
        }
        return c + '|||' + co;
    }

    public static String buildRecordName(String campaignName, String companyName) {
        String c = String.isBlank(campaignName) ? 'Campaign' : campaignName.trim();
        String co = String.isBlank(companyName) ? 'Company' : companyName.trim();
        String combined = c + ' — ' + co;
        return combined.length() > 80 ? combined.substring(0, 80) : combined;
    }

    private static String normalizePart(String value) {
        if (String.isBlank(value)) {
            return '';
        }
        return value.trim().toLowerCase();
    }
}