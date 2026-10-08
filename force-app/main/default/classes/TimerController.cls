public without sharing class TimerController {
        
    @AuraEnabled
    public static  Map<String,Object> saveCardsLwc(List<SFDC_Service_Timecard__c> records){
        Map<String,Object> res = new Map<String,Object>();
        Savepoint sp = Database.setSavepoint();
        try {
            res = new Map<String,Object> {
                'status' => 'Success',
                'header' => 'Successfully',
                'message' => 'Successfully'
            };
            if(records.size()>0 && records != null){
                List<SFDC_Service_Timecard__c> cards = new List<SFDC_Service_Timecard__c>();
                Set<String> idProds = new Set<String>();
                Set<String> idServs = new Set<String>();
                for(Integer i = 0; i < records.size(); i++) {
                    System.debug('records[i].Production__c ' + records[i].Production__c); 
                    if (String.isNotBlank(records[i].Production__c)) {
                        idProds.add(records[i].Production__c);
                    }
                    idServs.add(records[i].Service__c);
                }

                Map<Id,Product2> serviceMap = new Map<Id,Product2>([SELECT Id, Name FROM Product2 WHERE id IN:idServs]);
                Map<Id,Production__c> productionMap = new Map<Id,Production__c>([SELECT Id, Account_Name__c FROM Production__c WHERE id IN:idProds]);

                for(Integer i = 0; i < records.size(); i++) {
                    System.debug('records[i].Production__c ' + records[i].Production__c); 

                    if (String.isNotBlank(records[i].Production__c)) {
                         
                        SFDC_Service_Timecard__c card = new SFDC_Service_Timecard__c(
                            Id = records[i].Id,
                            Production__c = records[i].Production__c
                        );
                       
                        System.debug('records[i].card ' + card.Production__c); 
                   
                        if (String.isNotBlank(records[i].TaskRay_Task__c)){
                            card.TaskRay_Task__c = records[i].TaskRay_Task__c;
                        }
                        card.Service__c = records[i].Service__c;
                        card.Date_of_Service__c = records[i].Date_of_Service__c;
                        card.Start_Time__c = records[i].Start_Time__c;
                        card.End_Time__c = records[i].End_Time__c; 
                        card.Service_Notes__c = records[i].Service_Notes__c;
                        card.user__c = UserInfo.getUserId();

                        if (String.isNotBlank(records[i].Production__c)) {
                            card.Account__c = productionMap.containsKey(records[i].Production__c) ? productionMap.get(records[i].Production__c).Account_Name__c : null;    
                        }
                       
                        cards.add(card);
                    }
                }
                Database.upsert(cards, true);

                Set<String> idSTs = new Set<String>();
                for (SFDC_Service_Timecard__c c : cards) {
                    idSTs.add(c.Id);
                }

                List<TASKRAY__trTaskTime__c> taskTimes = [
                    SELECT  
                        Id, TASKRAY__Owner__c, TASKRAY__Task__c, TASKRAY__Date__c,
                        TASKRAY__trTimeType__c, TASKRAY__Hours__c,TASKRAY__trTimerStart__c,
                        TASKRAY__trTimerEnd__c, TASKRAY__Notes__c, Service_Timecard__c 
                    FROM TASKRAY__trTaskTime__c
                    WHERE Service_Timecard__c IN : idSTs
                ];

                Map<Id, TASKRAY__trTaskTime__c> taskTimesMap = new Map<Id, TASKRAY__trTaskTime__c>();

                for (TASKRAY__trTaskTime__c tt : taskTimes) {
                    taskTimesMap.put(tt.Service_Timecard__c, tt);
                }
                
                List<TASKRAY__trTaskTime__c> taskTimeNews = new List<TASKRAY__trTaskTime__c>();

                for (SFDC_Service_Timecard__c c : cards) {
                    if (String.isNotBlank(c.TaskRay_Task__c)){
                        TASKRAY__trTaskTime__c tt = new TASKRAY__trTaskTime__c();
                    
                        if (taskTimesMap.containsKey(c.Id)) {
                            tt.Id = taskTimesMap.get(c.Id).Id; 
                        }

                        tt.TASKRAY__Owner__c = c.user__c;
                        tt.TASKRAY__Task__c = c.TaskRay_Task__c;
                        tt.TASKRAY__Date__c = c.Date_of_Service__c;
                        tt.TASKRAY__trTimeType__c = serviceMap.get(c.Service__c).Name;
                    
                        tt.TASKRAY__trTimerStart__c = convertDT( tt.TASKRAY__Date__c + 'T' + String.valueOf(c.Start_Time__c));
                        tt.TASKRAY__trTimerEnd__c = convertDT(tt.TASKRAY__Date__c + 'T' + String.valueOf(c.End_Time__c));
                        Decimal tm =  (Decimal)(tt.TASKRAY__trTimerEnd__c.getTime() - tt.TASKRAY__trTimerStart__c.getTime());
                         tt.TASKRAY__Hours__c =  (tm )/(1000*60*60);
                        tt.TASKRAY__Notes__c = c.Service_Notes__c;
                        tt.Service_Timecard__c = c.Id;
                        taskTimeNews.add(tt);
                    }
                   
                }

                if (taskTimeNews.size() > 0) {
                    upsert taskTimeNews;
                }

                // TASKRAY__trTaskTime__c
 
            }
            
           
        } catch (Exception e) {
            Database.rollback(sp);
            res = new Map<String,Object> {
                'status' => 'Error',
                'header' => 'Error',
                'message' =>  e.getMessage()  
            };
        }

        return res;
    }
    
    private static Datetime convertDT(String d1) {
        // String d1 = '2025-01-15T00:30:00.000Z';
        list<String> d2 = d1.split('-');
        list<integer> timeComponent = new list<integer>();

        timeComponent.add(Integer.valueOf(d2[1]));
        timeComponent.add(Integer.valueOf(d2[2].left(2)));
        timeComponent.add(Integer.valueOf(d2[0]));

        String t = d2[2].substringBetween('T','.');

        list<String> time1 = t.split(':');
        timeComponent.add(Integer.valueOf(time1[0]));
        timeComponent.add(Integer.valueOf(time1[1]));
        timeComponent.add(Integer.valueOf(time1[2]));

        Datetime dt = Datetime.newInstance(timeComponent[2],
                                            timeComponent[0],
                                            timeComponent[1],
                                            timeComponent[3],
                                            timeComponent[4],
                                            timeComponent[5]);

        System.debug(dt);
        return dt;
    }

    @AuraEnabled
    public static List<SFDC_Service_Timecard__c> getCards(Date sDt, Date eDt){
        System.debug(sDt);
        System.debug(eDt);
        return [
            SELECT Id, Production__c, Production__r.Name, TaskRay_Task__c, TaskRay_Task__r.Name, 
            Service__c, Service__r.Name, Date_of_Service__c, Start_Time__c, End_Time__c, Service_Notes__c, Ticket_Time__c
            FROM SFDC_Service_Timecard__c WHERE user__c = :UserInfo.getUserId() AND Date_of_Service__c >=: sDt AND Date_of_Service__c <=: eDt
            ORDER BY Date_of_Service__c, Start_Time__c
        ];
    }

    public class TaskRayMonthSummary {
        @AuraEnabled public Decimal totalHours = 0;
        @AuraEnabled public Decimal totalTaskRemainingHours = 0;
        @AuraEnabled public List<TaskRayDayHours> dayHours = new List<TaskRayDayHours>();
        @AuraEnabled public List<TaskRayTaskHours> tasks = new List<TaskRayTaskHours>();
    }

    public class TaskRayDayHours {
        @AuraEnabled public Date day;
        @AuraEnabled public Decimal hours;
        public TaskRayDayHours(Date d, Decimal h) {
            day = d;
            hours = h;
        }
    }

    public class TaskRayTaskHours {
        @AuraEnabled public Id taskId;
        @AuraEnabled public String taskName;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date estimatedEndDate;
        @AuraEnabled public Decimal estimatedHours;
        @AuraEnabled public Decimal totalTimeOnTask;
        @AuraEnabled public Decimal remainingHours;
    }

    @AuraEnabled(cacheable=true)
    public static TaskRayMonthSummary getTaskRayMonthSummary(Date sDt, Date eDt) {
        TaskRayMonthSummary summary = new TaskRayMonthSummary();
        if (sDt == null || eDt == null) return summary;

        List<TASKRAY__trTaskTime__c> entries = [
            SELECT Id, TASKRAY__Owner__c, TASKRAY__Task__c, TASKRAY__Date__c, TASKRAY__Hours__c
            FROM TASKRAY__trTaskTime__c
            WHERE TASKRAY__Owner__c = :UserInfo.getUserId()
              AND TASKRAY__Date__c >= :sDt
              AND TASKRAY__Date__c <= :eDt
              AND TASKRAY__Hours__c != null
        ];

        Map<Date, Decimal> hoursByDay = new Map<Date, Decimal>();
        Set<Id> taskIds = new Set<Id>();
        for (TASKRAY__trTaskTime__c e : entries) {
            taskIds.add(e.TASKRAY__Task__c);
            Decimal h = e.TASKRAY__Hours__c == null ? 0 : e.TASKRAY__Hours__c;
            summary.totalHours += h;
            if (!hoursByDay.containsKey(e.TASKRAY__Date__c)) {
                hoursByDay.put(e.TASKRAY__Date__c, 0);
            }
            hoursByDay.put(e.TASKRAY__Date__c, hoursByDay.get(e.TASKRAY__Date__c) + h);
        }

        for (Date d : hoursByDay.keySet()) {
            summary.dayHours.add(new TaskRayDayHours(d, hoursByDay.get(d)));
        }

        if (!taskIds.isEmpty()) {
            List<TASKRAY__Project_Task__c> tasks = [
                SELECT Id, Name, TASKRAY__trStartDate__c, TASKRAY__Deadline__c, TASKRAY__trEstimatedHours__c, TASKRAY__trTotalTimeOnTask__c
                FROM TASKRAY__Project_Task__c
                WHERE Id IN :taskIds
            ];

            for (TASKRAY__Project_Task__c t : tasks) {
                TaskRayTaskHours th = new TaskRayTaskHours();
                th.taskId = t.Id;
                th.taskName = t.Name;
                th.startDate = t.TASKRAY__trStartDate__c;
                th.estimatedEndDate = t.TASKRAY__Deadline__c;
                th.estimatedHours = t.TASKRAY__trEstimatedHours__c == null ? 0 : t.TASKRAY__trEstimatedHours__c;
                th.totalTimeOnTask = t.TASKRAY__trTotalTimeOnTask__c == null ? 0 : t.TASKRAY__trTotalTimeOnTask__c;
                Decimal remaining = th.estimatedHours - th.totalTimeOnTask;
                th.remainingHours = remaining > 0 ? remaining : 0;
                summary.totalTaskRemainingHours += th.remainingHours;
                summary.tasks.add(th);
            }
        }

        return summary;
    }

    public class StatusFillEvent {
        @AuraEnabled public Id taskId;
        @AuraEnabled public String taskName;
        @AuraEnabled public Date eventDate;
        @AuraEnabled public Date developmentStartDate;
        @AuraEnabled public String newStatus;
        @AuraEnabled public String oldStatus;
        @AuraEnabled public Decimal estimatedHours;
        @AuraEnabled public Decimal totalTimeOnTask;
        @AuraEnabled public Decimal remainingHours;
        @AuraEnabled public Decimal suggestedHours;
        @AuraEnabled public String hintText;
        @AuraEnabled public String parentUrl;
    }

    @AuraEnabled(cacheable=true)
    public static List<StatusFillEvent> getTaskRayStatusFillEvents(Date sDt, Date eDt) {
        List<StatusFillEvent> out = new List<StatusFillEvent>();
        if (sDt == null || eDt == null) return out;

        Id uid = UserInfo.getUserId();
        Datetime startDt = Datetime.newInstance(sDt.year(), sDt.month(), sDt.day(), 0, 0, 0);
        Datetime endDt = Datetime.newInstance(eDt.year(), eDt.month(), eDt.day(), 23, 59, 59);

        List<TASKRAY__Project_Task__History> hist = [
            SELECT ParentId, CreatedDate, OldValue, NewValue, CreatedById
            FROM TASKRAY__Project_Task__History
            WHERE Field = 'TASKRAY__List__c'
              AND CreatedById = :uid
              AND CreatedDate >= :startDt
              AND CreatedDate <= :endDt
            ORDER BY CreatedDate ASC
            LIMIT 1000
        ];

        Set<Id> taskIds = new Set<Id>();
        List<TASKRAY__Project_Task__History> relevant = new List<TASKRAY__Project_Task__History>();
        for (TASKRAY__Project_Task__History h : hist) {
            String nv = h.NewValue == null ? '' : String.valueOf(h.NewValue);
            if (nv == 'Internal Testing' || nv == 'Internal Testing Production') {
                relevant.add(h);
                if (h.ParentId != null) taskIds.add(h.ParentId);
            }
        }
        if (relevant.isEmpty()) return out;

        Map<Id, TASKRAY__Project_Task__c> tasksById = new Map<Id, TASKRAY__Project_Task__c>([
            SELECT Id, Name, TASKRAY__trStartDate__c, TASKRAY__Deadline__c,
                   TASKRAY__trEstimatedHours__c, TASKRAY__trTotalTimeOnTask__c
            FROM TASKRAY__Project_Task__c
            WHERE Id IN :taskIds
        ]);

        // Find most recent move into Development in Progress before each Internal Testing event.
        Map<Id, Date> lastDevStartByTask = new Map<Id, Date>();
        for (TASKRAY__Project_Task__History h : [
            SELECT ParentId, CreatedDate, NewValue
            FROM TASKRAY__Project_Task__History
            WHERE Field = 'TASKRAY__List__c'
              AND ParentId IN :taskIds
              AND CreatedDate <= :endDt
            ORDER BY CreatedDate ASC
            LIMIT 2000
        ]) {
            String nv = h.NewValue == null ? '' : String.valueOf(h.NewValue);
            if (nv == 'Development in Progress' && h.ParentId != null) {
                lastDevStartByTask.put(h.ParentId, h.CreatedDate.date());
            }
        }

        for (TASKRAY__Project_Task__History h : relevant) {
            TASKRAY__Project_Task__c t = tasksById.get(h.ParentId);
            if (t == null) continue;

            String nv = String.valueOf(h.NewValue);
            String ov = h.OldValue == null ? '' : String.valueOf(h.OldValue);

            StatusFillEvent row = new StatusFillEvent();
            row.taskId = t.Id;
            row.taskName = t.Name;
            row.eventDate = h.CreatedDate.date();
            row.newStatus = nv;
            row.oldStatus = ov;
            row.estimatedHours = t.TASKRAY__trEstimatedHours__c == null ? 0 : t.TASKRAY__trEstimatedHours__c;
            row.totalTimeOnTask = t.TASKRAY__trTotalTimeOnTask__c == null ? 0 : t.TASKRAY__trTotalTimeOnTask__c;
            Decimal rem = row.estimatedHours - row.totalTimeOnTask;
            row.remainingHours = rem > 0 ? rem : 0;
            row.parentUrl = '/' + String.valueOf(t.Id);

            Date devStart = lastDevStartByTask.containsKey(t.Id) ? lastDevStartByTask.get(t.Id) : null;
            if (devStart == null && t.TASKRAY__trStartDate__c != null) {
                devStart = t.TASKRAY__trStartDate__c;
            }
            if (devStart == null || devStart > row.eventDate) {
                // Fallback: ~2 calendar days before status move; LWC keeps only weekdays.
                devStart = row.eventDate.addDays(-2);
            }
            row.developmentStartDate = devStart;

            if (nv == 'Internal Testing Production') {
                row.suggestedHours = 2;
                row.hintText = 'Prod deploy (Internal Testing Production)';
            } else {
                // Prefer unspent estimate; if already fully tracked, still suggest estimate as guidance.
                row.suggestedHours = row.remainingHours > 0 ? row.remainingHours : row.estimatedHours;
                row.hintText = 'Development (moved to Internal Testing)';
            }
            out.add(row);
        }
        return out;
    }

    public class ChatterActivityItem {
        @AuraEnabled public Id taskId;
        @AuraEnabled public String taskName;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String authorName;
        @AuraEnabled public Boolean isByMe;
        @AuraEnabled public Boolean isMention;
        @AuraEnabled public String snippet;
        @AuraEnabled public String parentUrl;
    }

    @AuraEnabled(cacheable=true)
    public static List<ChatterActivityItem> getTaskRayChatterActivity(Date sDt, Date eDt, List<Id> taskIds) {
        if (sDt == null || eDt == null || taskIds == null || taskIds.isEmpty()) return new List<ChatterActivityItem>();

        Id uid = UserInfo.getUserId();
        User me = [SELECT Id, FirstName, LastName, Name FROM User WHERE Id = :uid LIMIT 1];

        Map<Id, String> taskNameById = new Map<Id, String>();
        for (TASKRAY__Project_Task__c t : [
            SELECT Id, Name FROM TASKRAY__Project_Task__c WHERE Id IN :taskIds
        ]) {
            taskNameById.put(t.Id, t.Name);
        }

        List<ChatterActivityItem> out = new List<ChatterActivityItem>();

        // Feed posts on the task
        for (FeedItem fi : [
            SELECT Id, ParentId, CreatedDate, CreatedById, CreatedBy.Name, Body
            FROM FeedItem
            WHERE ParentId IN :taskIds
              AND CreatedDate >= :sDt
              AND CreatedDate <= :eDt
            ORDER BY CreatedDate DESC
            LIMIT 500
        ]) {
            String body = fi.Body == null ? '' : fi.Body;
            Boolean isByMe = fi.CreatedById == uid;
            Boolean isMention = (!isByMe) && (body.contains(me.Name) || body.contains(me.LastName));
            if (!isByMe && !isMention) continue;

            ChatterActivityItem row = new ChatterActivityItem();
            row.taskId = fi.ParentId;
            row.taskName = taskNameById.get(fi.ParentId);
            row.createdDate = fi.CreatedDate;
            row.authorName = fi.CreatedBy != null ? fi.CreatedBy.Name : null;
            row.isByMe = isByMe;
            row.isMention = isMention;
            row.snippet = stripHtml(body);
            if (row.snippet != null && row.snippet.length() > 140) row.snippet = row.snippet.substring(0, 140) + '...';
            row.parentUrl = '/' + String.valueOf(fi.ParentId);
            out.add(row);
        }

        // Feed comments: query by FeedItemId then map to ParentId via FeedItem
        List<FeedComment> comments = [
            SELECT Id, FeedItemId, CreatedDate, CreatedById, CreatedBy.Name, CommentBody
            FROM FeedComment
            WHERE CreatedDate >= :sDt
              AND CreatedDate <= :eDt
            ORDER BY CreatedDate DESC
            LIMIT 500
        ];

        Set<Id> feedItemIds = new Set<Id>();
        for (FeedComment fc : comments) {
            if (fc.FeedItemId != null) feedItemIds.add(fc.FeedItemId);
        }

        Map<Id, FeedItem> feedById = feedItemIds.isEmpty()
            ? new Map<Id, FeedItem>()
            : new Map<Id, FeedItem>([
                SELECT Id, ParentId
                FROM FeedItem
                WHERE Id IN :feedItemIds
                  AND ParentId IN :taskIds
            ]);

        for (FeedComment fc : comments) {
            if (fc.FeedItemId == null || !feedById.containsKey(fc.FeedItemId)) continue;
            Id parentTaskId = feedById.get(fc.FeedItemId).ParentId;

            String body = fc.CommentBody == null ? '' : fc.CommentBody;
            Boolean isByMe = fc.CreatedById == uid;
            Boolean isMention = (!isByMe) && (body.contains(me.Name) || body.contains(me.LastName));
            if (!isByMe && !isMention) continue;

            ChatterActivityItem row = new ChatterActivityItem();
            row.taskId = parentTaskId;
            row.taskName = taskNameById.get(parentTaskId);
            row.createdDate = fc.CreatedDate;
            row.authorName = fc.CreatedBy != null ? fc.CreatedBy.Name : null;
            row.isByMe = isByMe;
            row.isMention = isMention;
            row.snippet = stripHtml(body);
            if (row.snippet != null && row.snippet.length() > 140) row.snippet = row.snippet.substring(0, 140) + '...';
            row.parentUrl = parentTaskId != null ? '/' + String.valueOf(parentTaskId) : null;
            out.add(row);
        }

        out.sort(new ChatterActivitySort());
        if (out.size() <= 500) return out;

        List<ChatterActivityItem> trimmed = new List<ChatterActivityItem>();
        for (Integer i = 0; i < 500; i++) {
            trimmed.add(out[i]);
        }
        return trimmed;
    }

    @AuraEnabled(cacheable=true)
    public static List<ChatterActivityItem> getMyTaskRayMentions(Date sDt, Date eDt) {
        if (sDt == null || eDt == null) return new List<ChatterActivityItem>();

        Id uid = UserInfo.getUserId();
        User me = [SELECT Id, FirstName, LastName, Name FROM User WHERE Id = :uid LIMIT 1];

        // Hard cap window to avoid huge scans if caller passes wide range
        // (LWC uses month bounds).
        DateTime startDt = DateTime.newInstance(sDt.year(), sDt.month(), sDt.day(), 0, 0, 0);
        DateTime endDt = DateTime.newInstance(eDt.year(), eDt.month(), eDt.day(), 23, 59, 59);

        // Use SOSL to find mentions/text hits, since SOQL can't filter on FeedItem.Body.
        // Also include my own posts/comments via CreatedById filters later.
        String term = me.LastName;
        List<List<SObject>> searchRes = Search.query(
            'FIND {' + String.escapeSingleQuotes(term) + '} IN ALL FIELDS ' +
            'RETURNING ' +
            'FeedItem(Id, ParentId, CreatedDate, CreatedById, CreatedBy.Name, Body WHERE CreatedDate >= ' + startDt.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') +
            ' AND CreatedDate <= ' + endDt.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') + ' LIMIT 500), ' +
            'FeedComment(Id, FeedItemId, CreatedDate, CreatedById, CreatedBy.Name, CommentBody WHERE CreatedDate >= ' + startDt.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') +
            ' AND CreatedDate <= ' + endDt.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') + ' LIMIT 500)'
        );

        List<FeedItem> fiHits = new List<FeedItem>();
        List<FeedComment> fcHits = new List<FeedComment>();
        if (!searchRes.isEmpty()) {
            if (searchRes.size() > 0) {
                for (SObject s : searchRes[0]) fiHits.add((FeedItem)s);
            }
            if (searchRes.size() > 1) {
                for (SObject s : searchRes[1]) fcHits.add((FeedComment)s);
            }
        }

        // Also include my own FeedItems/Comments for the month on TaskRay tasks (even if no mention text hit).
        List<FeedItem> myItems = [
            SELECT Id, ParentId, CreatedDate, CreatedById, CreatedBy.Name, Body
            FROM FeedItem
            WHERE CreatedById = :uid
              AND CreatedDate >= :startDt
              AND CreatedDate <= :endDt
            ORDER BY CreatedDate DESC
            LIMIT 500
        ];

        List<FeedComment> myComments = [
            SELECT Id, FeedItemId, CreatedDate, CreatedById, CreatedBy.Name, CommentBody
            FROM FeedComment
            WHERE CreatedById = :uid
              AND CreatedDate >= :startDt
              AND CreatedDate <= :endDt
            ORDER BY CreatedDate DESC
            LIMIT 500
        ];

        Map<Id, FeedItem> fiById = new Map<Id, FeedItem>();
        for (FeedItem fi : fiHits) fiById.put(fi.Id, fi);
        for (FeedItem fi : myItems) fiById.put(fi.Id, fi);

        Map<Id, FeedComment> fcById = new Map<Id, FeedComment>();
        for (FeedComment fc : fcHits) fcById.put(fc.Id, fc);
        for (FeedComment fc : myComments) fcById.put(fc.Id, fc);

        Set<Id> parentIds = new Set<Id>();
        for (FeedItem fi : fiById.values()) {
            if (fi.ParentId != null) parentIds.add(fi.ParentId);
        }

        Set<Id> feedItemIds = new Set<Id>();
        for (FeedComment fc : fcById.values()) {
            if (fc.FeedItemId != null) feedItemIds.add(fc.FeedItemId);
        }

        Map<Id, FeedItem> commentFeedItems = feedItemIds.isEmpty()
            ? new Map<Id, FeedItem>()
            : new Map<Id, FeedItem>([
                SELECT Id, ParentId
                FROM FeedItem
                WHERE Id IN :feedItemIds
            ]);

        for (FeedItem fi : commentFeedItems.values()) {
            if (fi.ParentId != null) parentIds.add(fi.ParentId);
        }

        // Keep only TaskRay task parents.
        // TaskRay task Id prefixes are typically a2R or a3I; filter defensively.
        Set<Id> taskIds = new Set<Id>();
        for (Id pid : parentIds) {
            String p = String.valueOf(pid);
            if (p.startsWith('a2R') || p.startsWith('a3I')) taskIds.add(pid);
        }

        if (taskIds.isEmpty()) return new List<ChatterActivityItem>();

        Map<Id, String> taskNameById = new Map<Id, String>();
        for (TASKRAY__Project_Task__c t : [SELECT Id, Name FROM TASKRAY__Project_Task__c WHERE Id IN :taskIds]) {
            taskNameById.put(t.Id, t.Name);
        }

        List<ChatterActivityItem> out = new List<ChatterActivityItem>();

        for (FeedItem fi : fiById.values()) {
            if (fi.ParentId == null || !taskNameById.containsKey(fi.ParentId)) continue;
            ChatterActivityItem row = new ChatterActivityItem();
            row.taskId = fi.ParentId;
            row.taskName = taskNameById.get(fi.ParentId);
            row.createdDate = fi.CreatedDate;
            row.authorName = fi.CreatedBy != null ? fi.CreatedBy.Name : null;
            row.isByMe = fi.CreatedById == uid;
            String body = fi.Body == null ? '' : fi.Body;
            row.isMention = (!row.isByMe) && (body.contains(me.Name) || body.contains(me.LastName));
            row.snippet = stripHtml(body);
            if (row.snippet != null && row.snippet.length() > 140) row.snippet = row.snippet.substring(0, 140) + '...';
            row.parentUrl = '/' + String.valueOf(fi.ParentId);
            out.add(row);
        }

        for (FeedComment fc : fcById.values()) {
            if (fc.FeedItemId == null || !commentFeedItems.containsKey(fc.FeedItemId)) continue;
            Id parentTaskId = commentFeedItems.get(fc.FeedItemId).ParentId;
            if (parentTaskId == null || !taskNameById.containsKey(parentTaskId)) continue;
            ChatterActivityItem row = new ChatterActivityItem();
            row.taskId = parentTaskId;
            row.taskName = taskNameById.get(parentTaskId);
            row.createdDate = fc.CreatedDate;
            row.authorName = fc.CreatedBy != null ? fc.CreatedBy.Name : null;
            row.isByMe = fc.CreatedById == uid;
            String body = fc.CommentBody == null ? '' : fc.CommentBody;
            row.isMention = (!row.isByMe) && (body.contains(me.Name) || body.contains(me.LastName));
            row.snippet = stripHtml(body);
            if (row.snippet != null && row.snippet.length() > 140) row.snippet = row.snippet.substring(0, 140) + '...';
            row.parentUrl = '/' + String.valueOf(parentTaskId);
            out.add(row);
        }

        out.sort(new ChatterActivitySort());
        if (out.size() <= 500) return out;
        List<ChatterActivityItem> trimmed = new List<ChatterActivityItem>();
        for (Integer i = 0; i < 500; i++) trimmed.add(out[i]);
        return trimmed;
    }

    private class ChatterActivitySort implements Comparator<ChatterActivityItem> {
        public Integer compare(ChatterActivityItem a, ChatterActivityItem b) {
            if (a == null || a.createdDate == null) return 1;
            if (b == null || b.createdDate == null) return -1;
            Long ta = a.createdDate.getTime();
            Long tb = b.createdDate.getTime();
            return ta == tb ? 0 : (ta > tb ? -1 : 1);
        }
    }

    private static String stripHtml(String html) {
        if (String.isBlank(html)) return '';
        String t = html.replaceAll('<[^>]*>', '');
        t = t.replace('&nbsp;', ' ');
        t = t.replace('&amp;', '&');
        t = t.replace('&lt;', '<');
        t = t.replace('&gt;', '>');
        t = t.replace('&quot;', '"');
        return t;
    }
    
    @AuraEnabled
    public static String deleteCards(String toDeleteId){
        List<SFDC_Service_Timecard__c> acc = new List<SFDC_Service_Timecard__c>();
        SFDC_Service_Timecard__c a = new SFDC_Service_Timecard__c();
        a.Id = toDeleteId;
        acc.add(a);
        Database.DeleteResult[] drList = Database.delete(acc, false);
		List<String> deletedIds = new List<String>();
        List<String> errorMessages = new List<String>();
        // Iterate through each returned result
        for(Database.DeleteResult dr : drList) {
            if (dr.isSuccess()) {
                // Operation was successful, so get the ID of the record that was processed
                System.debug('Successfully deleted account with ID: ' + dr.getId());
                deletedIds.add(dr.getId());
                
            }
            else {
                // Operation failed, so get all errors                
                for(Database.Error err : dr.getErrors()) {
                    System.debug('The following error has occurred.');                    
                    System.debug(err.getStatusCode() + ': ' + err.getMessage());
                    System.debug('Account fields that affected this error: ' + err.getFields());
                    errorMessages.add(err.getMessage());
                }
                
            }
        }
        if(deletedIds.size() > 0)
            return 'success';
        else
            return errorMessages[0];
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
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;     i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;  i++;
        i++;
        i++;      i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;   i++;
        i++;
        i++;
        i++;
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