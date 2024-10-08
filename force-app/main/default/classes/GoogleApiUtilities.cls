public inherited sharing class GoogleApiUtilities 
{
    @future(callout=true)
    public static void createGoogleEventsFromSalesforceEvents(Set<Id> salesforceEventIds)
    {
        String methodType = 'POST'; 
        String endpointUrl = 'callout:GoogleCalendarPerUser/primary/events?sendUpdates=all&conferenceDataVersion=1';
        String reqBody; 
        Map<String, String> headersMap = new Map<String, String>();
        headersMap.put('Content-Type', 'application/json');
        headersMap.put('Accept', 'application/json');

        List<Event> sfEventsToUpdate = new List<Event>();
        
        for(Event evt : [SELECT Id,JSON_Body__c, JSON_Body2__c, JSON_Body3__c, JSON_Body4__c, Send_Google_Meet_Link_to_Attendees__c, Google_Meet_Link__c, Subject, Location, IsAllDayEvent, ActivityDateTime, ActivityDate, StartDateTime, EndDateTime, EndDate, Description, Attendees__c, Google_Event_Id__c, Google_Sync_Details__c, Google_Sync_Status__c 
                            FROM Event
                            WHERE JSON_Body__c != '' 
                            AND Google_Sync_Status__c = 'PENDING'
                            AND Id IN :salesforceEventIds])
        {
            String completeJsonBody = '';

            if(String.isNotBlank(evt.JSON_Body__c))
            {
                 completeJsonBody += evt.JSON_Body__c;
            }

            if(String.isNotBlank(evt.JSON_Body2__c))
            {
                completeJsonBody += evt.JSON_Body2__c;
            }

            if(String.isNotBlank(evt.JSON_Body3__c))
            {
                completeJsonBody += evt.JSON_Body3__c;
            }

            if(String.isNotBlank(evt.JSON_Body4__c))
            {
                completeJsonBody += evt.JSON_Body4__c;
            }

            reqBody = completeJsonBody;
            Map<String, Object> calloutResponse = doCalloutToGoogleApi(methodType, endpointUrl, reqBody, headersMap);

            if(calloutResponse != null && (Boolean)calloutResponse.get('isSuccess'))
            {
                System.debug('Successfull');
                evt.Google_Event_Id__c = (String)calloutResponse.get('googleEventId');
                evt.Google_Sync_Status__c = 'SUCCESS';
                evt.Google_Sync_Details__c = 'Successfully created Google Event with Id: '+evt.Google_Event_Id__c +'. Last Sync time: '+System.now();

                if(calloutResponse.get('googleMeetLink') != null)
                {
                    evt.Google_Meet_Link__c = (String)calloutResponse.get('googleMeetLink');
                }

                sfEventsToUpdate.add(evt);
            }
            else
            {
                evt.Google_Sync_Status__c = 'FAILED';
                String errorMessage = (String)calloutResponse.get('errorMessage');
                evt.Google_Sync_Details__c = errorMessage.substring(0, Math.min(250, errorMessage.length()));
                sfEventsToUpdate.add(evt);
            }
        }
        
        if(sfEventsToUpdate.size() > 0)
        {
            update sfEventsToUpdate;
        }
    }




    @future(callout=true)
    public static void updateGoogleEventsFromSalesforceEvents(Set<Id> salesforceEventIds)
    {
        String methodType = 'PUT'; 
        String endpointUrl;
        String reqBody; 
        Map<String, String> headersMap = new Map<String, String>();
        headersMap.put('Content-Type', 'application/json');
        headersMap.put('Accept', 'application/json');

        List<Event> sfEventsToUpdate = new List<Event>();
        
        for(Event evt : [SELECT Id,JSON_Body__c, JSON_Body2__c, JSON_Body3__c, JSON_Body4__c, Send_Google_Meet_Link_to_Attendees__c, Google_Meet_Link__c, Subject, Location, IsAllDayEvent, ActivityDateTime, ActivityDate, StartDateTime, EndDateTime, EndDate, Description, Attendees__c, Google_Event_Id__c, Google_Sync_Details__c, Google_Sync_Status__c 
                            FROM Event
                            WHERE JSON_Body__c != '' 
                            AND Id IN :salesforceEventIds])
        {
            endpointUrl = 'callout:GoogleCalendarPerUser/primary/events/' + evt.Google_Event_Id__c + '?sendUpdates=all&conferenceDataVersion=1';

            String completeJsonBody = '';

            if(String.isNotBlank(evt.JSON_Body__c))
            {
                 completeJsonBody += evt.JSON_Body__c;
            }

            if(String.isNotBlank(evt.JSON_Body2__c))
            {
                completeJsonBody += evt.JSON_Body2__c;
            }

            if(String.isNotBlank(evt.JSON_Body3__c))
            {
                completeJsonBody += evt.JSON_Body3__c;
            }

            if(String.isNotBlank(evt.JSON_Body4__c))
            {
                completeJsonBody += evt.JSON_Body4__c;
            }

            reqBody = completeJsonBody;

            Map<String, Object> calloutResponse = doCalloutToGoogleApi(methodType, endpointUrl, reqBody, headersMap);

            if(calloutResponse != null && (Boolean)calloutResponse.get('isSuccess'))
            {
                System.debug('Successfull');
                //evt.Google_Event_Id__c = (String)calloutResponse.get('googleEventId');
                evt.Google_Sync_Status__c = 'SUCCESS';
                evt.Google_Sync_Details__c = 'Successfully updated Google Event with Id: '+evt.Google_Event_Id__c +'. Last Sync time: '+System.now();
                
                if(calloutResponse.get('googleMeetLink') != null)
                {
                    evt.Google_Meet_Link__c = (String)calloutResponse.get('googleMeetLink');
                }
                sfEventsToUpdate.add(evt);
            }
            else
            {
                evt.Google_Sync_Status__c = 'FAILED';
                String errorMessage = (String)calloutResponse.get('errorMessage');
                evt.Google_Sync_Details__c = errorMessage.substring(0, Math.min(250, errorMessage.length()));
                sfEventsToUpdate.add(evt);
            }
        }
        
        if(sfEventsToUpdate.size() > 0)
        {
            update sfEventsToUpdate;
        }
    }





    public static Map<String, Object> doCalloutToGoogleApi(String methodType, String endpointUrl,String reqBody, Map<String, String> headersMap)
    {
        System.debug('doCalloutToGoogleCalendarApi called');
        System.debug('methodType ='+methodType);
        System.debug('endpointUrl ='+endpointUrl);
        System.debug('reqBody ='+reqBody);

        HttpRequest req = new HttpRequest();
        req.setMethod(methodType);
        req.setEndpoint(endpointUrl);
        
        if(!methodType.equalsIgnoreCase('GET') && !methodType.equalsIgnoreCase('DELETE'))
        {
            req.setBody(reqBody);
        }

        for(String eachHeader : headersMap.keySet())
        {
            System.debug('Header Name:' + eachHeader);
            System.debug('Header value:' + headersMap.get(eachHeader));
            req.setHeader(eachHeader, headersMap.get(eachHeader));
        }

        Http h = new Http();
        
        try
        {
            HttpResponse res = h.send(req);

            System.debug('res='+res.getBody());
            System.debug('res status code='+res.getStatusCode());

            Map<String, Object> mappedResponse = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());

            if(res.getStatusCode() == 200 || res.getStatusCode() == 201)
            {
                return new Map<String, Object>{
                    'isSuccess'         => true,
                    'statusCode'        => res.getStatusCode(),
                    'googleMeetLink'    => mappedResponse.get('hangoutLink') != null ? (String)mappedResponse.get('hangoutLink') : null,
                    'googleEventId'     => (String)mappedResponse.get('id')
                };
            }
            else
            {
                return new Map<String, Object>{
                    'isSuccess'    => false,
                    'statusCode'   => res.getStatusCode(),
                    'errorMessage' => 'Error Details: '+ res.getBody()
                };
            }
        }
        catch (Exception e)
        {
            return new Map<String, Object>{
                'isSuccess'    => false,
                'statusCode'   => 0,
                'errorMessage' => 'Some exception occurred while creating Google Calendar Event: ' + e.getMessage()
                };
        }
    }
    
}