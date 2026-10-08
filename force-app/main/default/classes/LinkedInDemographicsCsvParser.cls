public with sharing class LinkedInDemographicsCsvParser {
    public class DemographicsRow {
        public String companyName;
        public String organizationId;
        public Decimal impressions;
        public Decimal clicks;
        public Decimal conversions;
    }

    public class ParseResult {
        public Date reportStart;
        public Date reportEnd;
        public List<DemographicsRow> rows = new List<DemographicsRow>();
        public Integer skippedRows = 0;
    }

    private static final String COMPANY_SEGMENT_HEADER = 'company name segment';

    public static ParseResult parse(String csvContent) {
        ParseResult result = new ParseResult();
        if (String.isBlank(csvContent)) {
            return result;
        }

        List<String> lines = csvContent.replace('\r\n', '\n').replace('\r', '\n').split('\n');
        for (String line : lines) {
            parseReportDates(line, result);
        }

        Integer headerIndex = findCompanySegmentHeaderIndex(lines);
        if (headerIndex < 0) {
            return result;
        }

        Map<String, Integer> columnIndex = mapHeaderColumns(parseCsvLine(lines[headerIndex]));
        Integer companyCol = columnIndex.get('company name segment');
        // LinkedIn CSV has "Impressions", then "Percent of Total Impressions", then "Clicks", etc.
        // We match exact keys first; fallback to any key containing the word.
        Integer impCol = firstKey(columnIndex, new List<String>{ 'impressions' });
        Integer clickCol = firstKey(columnIndex, new List<String>{ 'clicks' });
        Integer convCol = firstKey(columnIndex, new List<String>{ 'conversions' });

        for (Integer i = headerIndex + 1; i < lines.size(); i++) {
            String line = lines[i];
            if (String.isBlank(line)) {
                continue;
            }
            List<String> cells = parseCsvLine(line);
            if (cells.isEmpty()) {
                continue;
            }
            String firstCell = normalizeHeader(cells[0]);
            if (String.isBlank(firstCell)) {
                continue;
            }
            if (firstCell.contains('segment') && !firstCell.contains('company name')) {
                break;
            }
            if (firstCell.startsWith('report ') || firstCell.contains('demographics report')) {
                continue;
            }

            String companyName = getCell(cells, companyCol != null ? companyCol : 0);
            if (String.isBlank(companyName)) {
                result.skippedRows++;
                continue;
            }

            DemographicsRow row = new DemographicsRow();
            row.companyName = companyName.trim();
            row.impressions = parseNumber(getCell(cells, impCol));
            row.clicks = parseNumber(getCell(cells, clickCol));
            row.conversions = parseNumber(getCell(cells, convCol));
            result.rows.add(row);
        }
        return result;
    }

    private static Integer findCompanySegmentHeaderIndex(List<String> lines) {
        for (Integer i = 0; i < lines.size(); i++) {
            List<String> cells = parseCsvLine(lines[i]);
            if (cells.isEmpty()) {
                continue;
            }
            String first = normalizeHeader(cells[0]);
            if (first == COMPANY_SEGMENT_HEADER || first.contains(COMPANY_SEGMENT_HEADER)) {
                return i;
            }
        }
        return -1;
    }

    private static Map<String, Integer> mapHeaderColumns(List<String> headers) {
        Map<String, Integer> out = new Map<String, Integer>();
        for (Integer i = 0; i < headers.size(); i++) {
            String key = normalizeHeader(headers[i]);
            if (String.isNotBlank(key)) {
                out.put(key, i);
            }
        }
        return out;
    }

    private static void parseReportDates(String line, ParseResult result) {
        if (result.reportStart != null && result.reportEnd != null) {
            return;
        }
        String lower = line.toLowerCase();
        if (lower.contains('report start')) {
            result.reportStart = parseDateFromLine(line);
        } else if (lower.contains('report end')) {
            result.reportEnd = parseDateFromLine(line);
        }
    }

    private static Date parseDateFromLine(String line) {
        Matcher m = Pattern.compile('(\\d{1,2})/(\\d{1,2})/(\\d{4})').matcher(line);
        if (m.find()) {
            return Date.newInstance(
                Integer.valueOf(m.group(3)),
                Integer.valueOf(m.group(1)),
                Integer.valueOf(m.group(2))
            );
        }
        m = Pattern.compile('(\\d{4})-(\\d{2})-(\\d{2})').matcher(line);
        if (m.find()) {
            return Date.newInstance(
                Integer.valueOf(m.group(1)),
                Integer.valueOf(m.group(2)),
                Integer.valueOf(m.group(3))
            );
        }
        return null;
    }

    private static String getCell(List<String> cells, Integer index) {
        if (index == null || index < 0 || index >= cells.size()) {
            return null;
        }
        return cells[index];
    }

    private static Decimal parseNumber(String raw) {
        if (String.isBlank(raw)) {
            return 0;
        }
        String s = raw.replace('%', '').replace(',', '').replace('$', '').trim();
        if (String.isBlank(s)) {
            return 0;
        }
        try {
            return Decimal.valueOf(s);
        } catch (Exception e) {
            return 0;
        }
    }

    private static String normalizeHeader(String value) {
        return String.isBlank(value) ? '' : value.trim().toLowerCase();
    }

    /**
     * Returns the column index for the first exact key match from candidates.
     * Falls back to the first key that *starts with* the candidate (avoids "Percent of Total Impressions" stealing "impressions").
     */
    private static Integer firstKey(Map<String, Integer> idx, List<String> candidates) {
        for (String c : candidates) {
            if (idx.containsKey(c)) {
                return idx.get(c);
            }
        }
        for (String c : candidates) {
            for (String key : idx.keySet()) {
                if (key.startsWith(c) && !key.startsWith('percent')) {
                    return idx.get(key);
                }
            }
        }
        return null;
    }

    public static List<String> parseCsvLine(String line) {
        List<String> cells = new List<String>();
        if (line == null) {
            return cells;
        }
        // LinkedIn Campaign Manager exports are usually tab-separated; Excel "CSV" may use commas.
        String delimiter = line.contains('\t') ? '\t' : ',';
        Boolean inQuotes = false;
        String current = '';
        for (Integer i = 0; i < line.length(); i++) {
            String ch = line.substring(i, i + 1);
            if (ch == '"') {
                if (inQuotes && i + 1 < line.length() && line.substring(i + 1, i + 2) == '"') {
                    current += '"';
                    i++;
                } else {
                    inQuotes = !inQuotes;
                }
            } else if (ch == delimiter && !inQuotes) {
                cells.add(current);
                current = '';
            } else {
                current += ch;
            }
        }
        cells.add(current);
        return cells;
    }
}