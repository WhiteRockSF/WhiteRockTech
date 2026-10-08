@RestResource(urlMapping='/event')
global class SiteEventController{
   
    global class EventWrapper {
        
        public String title;
        public String clientId;
        public String type;
        public String url;
        public String ip;
        public String timezone;
        public String country;
        public String region;
        public String city;
        public Decimal latitude;
        public Decimal longitude;
    }

  @HttpGet
  global static String doGet() {     
    return 'doGet';
  }
 
   @HttpPost
    global static void doPost(){
     RestRequest request = RestContext.request;
        RestResponse response = RestContext.response;
        
        String json = request.requestBody.toString();
        EventWrapper ev = (EventWrapper) System.JSON.deserialize(json, EventWrapper.class);

        List<Site_Event__c> siteEvents = new List<Site_Event__c> ();
        String url = String.isNotBlank(ev.url) && ev.url.length() > 254 ? ev.url.substring(0, 254) : ev.url;
        siteEvents.add(
            new Site_Event__c (
                Resource__c = ev.title,
                Client_Id__c = ev.clientId,
                Type__c = ev.type,
                URL__c = url,
                Location__Latitude__s = ev.latitude,
                Location__Longitude__s = ev.longitude,
                Event_Date__c = System.now(),
                ip__c = ev.ip, 
                Time_Zone__c = ev.timezone,
                Country__c = ev.country,
                State__c = ev.region,
                City__c = ev.city,
                Description__c = ev.url
            )
        );
        
       insert siteEvents;

    }


}