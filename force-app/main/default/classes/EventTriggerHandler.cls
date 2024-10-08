public with sharing class EventTriggerHandler 
{
    /**
     * V. Imp class for checking recursion of trigger.
     * Lets us know if a trigger has already executed for a particular sObject record and action (e.g. before insert).
     * You might be thinking why cant we simply use a static boolean variable like :
     *  
     *  public static Boolean isAfterInserExecuted = false;
     *  
     *  But this is not accurate, especially in cases where more than 200 records are inserted in a single transaction.
     *  
     *  Here we use triggerRecursionCheckMap to store a unique execution id for each trigger context and we can then check for it and prevent
     */
    public static Map<String, Set<String>> mapOperationTypeToAlreadyProcessedRecords = new Map<String, Set<String>>();

    public static Boolean CanThisRecordBeProcessed(String operationType, String recordId)
    {
        if(!mapOperationTypeToAlreadyProcessedRecords.containsKey(operationType))
        {
            mapOperationTypeToAlreadyProcessedRecords.put(operationType, new Set<String>{recordId});
            return true;
        }
        else
        {
            // check if record is present
            Boolean isRecordPresent = mapOperationTypeToAlreadyProcessedRecords.get(operationType).contains(recordId);

            if(isRecordPresent)
            {
                return false;
            }
            else
            {
                mapOperationTypeToAlreadyProcessedRecords.get(operationType).add(recordId);
                return true;
            }
        }
    }
    

    // ABove recursion login is not working...will debug later
    //public static Boolean hasBeforeUpdateAlreadyExecuted = false;
    //public static Boolean hasAfterUpdateAlreadyExecuted = false;




    public static Map<String, Object> createGoogleEventPayload(Event evt) 
    {
        Map<String, Object> payload = new Map<String, Object>();

        // Add basic event details
        payload.put('summary', evt.Subject);
        payload.put('description', evt.Description);

        if(String.isNotBlank(evt.Location))
        {
            payload.put('location', evt.Location);
        }


        Map<String, Object> start = new Map<String, Object>();
        Map<String, Object> endInfo = new Map<String, Object>();

        if(evt.IsAllDayEvent)       
        {
            // Format only the date
            String startDate = evt.StartDateTime.format('yyyy-MM-dd');
            String endDate = evt.EndDateTime.format('yyyy-MM-dd');

            start.put('date', startDate);
            endInfo.put('date', endDate);
        }
        else
        {
            // Format as ISO 8601 with timezone offset for datetime
            String startDateTime = evt.StartDateTime.format('yyyy-MM-dd\'T\'HH:mm:ssZZZZZ');
            String endDateTime = evt.EndDateTime.format('yyyy-MM-dd\'T\'HH:mm:ssZZZZZ');

            start.put('dateTime', startDateTime);
            endInfo.put('dateTime', endDateTime);
        }


        payload.put('start', start);
        payload.put('end', endInfo);
        
        // Add attendees if present
        if (String.isNotBlank(evt.Attendees__c)) 
        {
            List<Map<String, Object>> attendees = new List<Map<String, Object>>();

            for (String attendeeEmail : evt.Attendees__c.split(',')) 
            {
                Map<String, Object> attendee = new Map<String, Object>();
                attendee.put('email', attendeeEmail.trim());
                attendees.add(attendee);
            }
            payload.put('attendees', attendees);
        }

        // Add Google Meet conference data if the checkbox is true
        if (evt.Send_Google_Meet_Link_to_Attendees__c)
        {
            Map<String, Object> conferenceData = new Map<String, Object>();
            Map<String, Object> createRequest = new Map<String, Object>();
            
            // Generate a request ID
            String requestId = 'unique-request-id-' + System.UUID.randomUUID().toString();

            // Add the conferenceSolutionKey for Google Meet
            Map<String, Object> conferenceSolutionKey = new Map<String, Object>();
            conferenceSolutionKey.put('type', 'hangoutsMeet');
            
            // Add the requestId and conferenceSolutionKey
            createRequest.put('requestId', requestId);
            createRequest.put('conferenceSolutionKey', conferenceSolutionKey);

            // Add to conferenceData
            conferenceData.put('createRequest', createRequest);
            
            // Add the conference data to the payload
            payload.put('conferenceData', conferenceData);
        }

        return payload;
    }




    public static void handleBeforeInsert(List<Event> newEvents)
    {
        for(Event eachEvent : newEvents)
        {
            // IMP: Since we donot have any id present in BEFORE_INSERT. Hence, creating a custom Id from combination of all possible unique identifiers avaiable on record
            String customId = 'EVENT-' + eachEvent.Subject + eachEvent.Location + eachEvent.EndDateTime;
            System.debug('customId ='+customId);
            if(CanThisRecordBeProcessed('BEFORE_INSERT', customId))
            {
                // All BEFORE INSERT trigger logic should be here

                /**
                 * Logic 1: Populate JSON_Body__c field on each event which can further be used for request body.
                 *          This is to be sent in POST callout to Google Calendar API
                 */

                /**
                 * We cannot have a long text area field so I have created 4 JSON_Body__c fields ech of length 255.
                 * I will be storing 250 characters max in each. Lets say if total length is 300 characters then I'll
                 * store first 250 characters in 1st field and remaining 50 in 2nd field.
                 * 
                 * This way, we can be sure that we will not hit the character limit in JSON_Body__c field.
                 * Hence max we can handle is 1000 characters although we can further expand.
                 */

                // Serialize the event payload to a JSON string
                String jsonBody = JSON.serialize(createGoogleEventPayload(eachEvent));
                Integer lengthOfJsonBody = jsonBody.length();
                System.debug('Length of JSON Body: ' + lengthOfJsonBody);

                // Define the max length for each field
                Integer maxFieldLength = 250;

                // Initialize the strings for each field
                String part1 = '';
                String part2 = '';
                String part3 = '';
                String part4 = '';

                // Check if the total length is less than or equal to 1000
                if (lengthOfJsonBody <= 1000) {
                    // Populate part1, part2, part3, part4 based on the length of the JSON body
                    if (lengthOfJsonBody > 0) {
                        part1 = jsonBody.substring(0, Math.min(maxFieldLength, lengthOfJsonBody));
                    }
                    if (lengthOfJsonBody > maxFieldLength) {
                        part2 = jsonBody.substring(maxFieldLength, Math.min(2 * maxFieldLength, lengthOfJsonBody));
                    }
                    if (lengthOfJsonBody > 2 * maxFieldLength) {
                        part3 = jsonBody.substring(2 * maxFieldLength, Math.min(3 * maxFieldLength, lengthOfJsonBody));
                    }
                    if (lengthOfJsonBody > 3 * maxFieldLength) {
                        part4 = jsonBody.substring(3 * maxFieldLength, Math.min(4 * maxFieldLength, lengthOfJsonBody));
                    }
                    
                    // Assign the parts to the respective fields on the event
                    eachEvent.JSON_Body__c = part1;
                    eachEvent.JSON_Body2__c = part2;
                    eachEvent.JSON_Body3__c = part3;
                    eachEvent.JSON_Body4__c = part4;

                    System.debug('Part 1: ' + part1);
                    System.debug('Part 2: ' + part2);
                    System.debug('Part 3: ' + part3);
                    System.debug('Part 4: ' + part4);
                } 
                else 
                {
                    System.debug('Error: JSON body exceeds the 1000 character limit.');
                }
 
            }
            else 
            {
                System.debug('Event with Id:'+eachEvent.Id + ' has aleady been processed in BEFORE_INSERT trigger. Skipping...');
            }
        }
    }





    public static void handleAfterInsert(Map<Id, Event> newMap)
    {
        Set<Id> eventIdsForGoogleCalendarSync = new Set<Id>();

        for(Id eachEventId : newMap.keySet())
        {
            if(CanThisRecordBeProcessed('AFTER_INSERT', eachEventId))
            {
                // All AFTER INSERT trigger logic should be here

                /**
                 * Logic 1: Populate eventIdsForGoogleCalendarSync which can be sent in a combined manner to future method 
                 *          for callout i.e. using just 1 future method for all or may be 2 if lets say records are 201 because
                 *          trigger processes 200 records at a time Hence if there 201 records it will execute 2 times.
                 */

                if(newMap.get(eachEventId).Google_Sync_Status__c == 'PENDING')
                {
                    eventIdsForGoogleCalendarSync.add(eachEventId);
                }
            }
            else 
            {
                System.debug('Event with Id:'+eachEventId + ' has aleady been processed in AFTER_INSERT trigger. Skipping...');
            }
        }

        // call future method to sync events to google calendar
        if(eventIdsForGoogleCalendarSync != null && eventIdsForGoogleCalendarSync.size() > 0)
        {
            GoogleApiUtilities.createGoogleEventsFromSalesforceEvents(eventIdsForGoogleCalendarSync);
        }
    }





    public static void handleBeforeUpdate(Map<Id, Event> oldMap, Map<Id, Event> newMap)
    {
        /*
        if(mapOperationTypeToAlreadyProcessedRecords == null)
        {
            System.debug('mapOperationTypeToAlreadyProcessedRecords is null. hence instantiating in handleBeforeUpdate');
            mapOperationTypeToAlreadyProcessedRecords = new Map<String, Set<String>>();
        }
        */
        System.debug('handleBeforeUpdate called');
        System.debug('mapOperationTypeToAlreadyProcessedRecords = ');

        for(String eachOpeationType: mapOperationTypeToAlreadyProcessedRecords.keySet())
        {
            System.debug('eachOperationType = '+eachOpeationType);
            System.debug('Rec Ids = '+mapOperationTypeToAlreadyProcessedRecords.get(eachOpeationType));
        }

        for(Event eachEvent : newMap.values())
        {
            if(CanThisRecordBeProcessed('BEFORE_UPDATE', eachEvent.Id))
            {
                System.debug('Event with id='+ eachEvent.Id +' can be processed for Before Update');
                // All BEFORE UPDATE trigger logic should be here

                /**
                 * Logic 1: Populate JSON_Body__c field on each event which can further be used for request body.
                 *          This is to be sent in POST callout to Google Calendar API
                 */

                if( eachEvent.Google_Sync_Status__c == oldMap.get(eachEvent.Id).Google_Sync_Status__c ) 
                {
                    // Serialize the event payload to a JSON string
                    String jsonBody = JSON.serialize(createGoogleEventPayload(eachEvent));
                    Integer lengthOfJsonBody = jsonBody.length();
                    System.debug('Length of JSON Body: ' + lengthOfJsonBody);

                    // Define the max length for each field
                    Integer maxFieldLength = 250;

                    // Initialize the strings for each field
                    String part1 = '';
                    String part2 = '';
                    String part3 = '';
                    String part4 = '';

                    // Check if the total length is less than or equal to 1000
                    if (lengthOfJsonBody <= 1000) {
                        // Populate part1, part2, part3, part4 based on the length of the JSON body
                        if (lengthOfJsonBody > 0) {
                            part1 = jsonBody.substring(0, Math.min(maxFieldLength, lengthOfJsonBody));
                        }
                        if (lengthOfJsonBody > maxFieldLength) {
                            part2 = jsonBody.substring(maxFieldLength, Math.min(2 * maxFieldLength, lengthOfJsonBody));
                        }
                        if (lengthOfJsonBody > 2 * maxFieldLength) {
                            part3 = jsonBody.substring(2 * maxFieldLength, Math.min(3 * maxFieldLength, lengthOfJsonBody));
                        }
                        if (lengthOfJsonBody > 3 * maxFieldLength) {
                            part4 = jsonBody.substring(3 * maxFieldLength, Math.min(4 * maxFieldLength, lengthOfJsonBody));
                        }
                        
                        // Assign the parts to the respective fields on the event
                        eachEvent.JSON_Body__c = part1;
                        eachEvent.JSON_Body2__c = part2;
                        eachEvent.JSON_Body3__c = part3;
                        eachEvent.JSON_Body4__c = part4;

                        System.debug('Part 1: ' + part1);
                        System.debug('Part 2: ' + part2);
                        System.debug('Part 3: ' + part3);
                        System.debug('Part 4: ' + part4);
                    } 
                    else 
                    {
                        System.debug('Error: JSON body exceeds the 1000 character limit.');
                    }
                }
            }
            else 
            {
                System.debug('Event with Id:'+eachEvent.Id + ' has aleady been processed in BEFORE_UPDATE trigger. Skipping...');
            }
        }
    }





    public static void handleAfterUpdate(Map<Id, Event> oldMap, Map<Id, Event> newMap)
    {
        /*
        if(mapOperationTypeToAlreadyProcessedRecords == null)
        {
            System.debug('mapOperationTypeToAlreadyProcessedRecords is null. hence instantiating in handleAfterUpdate');
            mapOperationTypeToAlreadyProcessedRecords = new Map<String, Set<String>>();
        }
        */
        System.debug('handleAfterUpdate called');
        System.debug('mapOperationTypeToAlreadyProcessedRecords = ');

        for(String eachOpeationType: mapOperationTypeToAlreadyProcessedRecords.keySet())
        {
            System.debug('eachOperationType = '+eachOpeationType);
            System.debug('Rec Ids = '+mapOperationTypeToAlreadyProcessedRecords.get(eachOpeationType));
        }

        Set<Id> eventIdsForGoogleCalendarSync = new Set<Id>();

        for(Event eachEvent : newMap.values())
        {
            if(CanThisRecordBeProcessed('AFTER_UPDATE', eachEvent.Id))
            {
                System.debug('Event with id='+ eachEvent.Id +' can be processed for AFter Update');
                // All AFTER_UPDATE trigger logic should be here

                /**
                 * Logic 1: Populate eventIdsForGoogleCalendarSync which can be sent in a combined manner to future method 
                 *          for callout i.e. using just 1 future method for all or may be 2 if lets say records are 201 because
                 *          trigger processes 200 records at a time Hence if there 201 records it will execute 2 times.
                 */

                if(String.isNotBlank(eachEvent.JSON_Body__c) && eachEvent.JSON_Body__c != oldMap.get(eachEvent.Id).JSON_Body__c)
                {
                    eventIdsForGoogleCalendarSync.add(eachEvent.Id);
                }
            }
            else 
            {
                System.debug('Event with Id:'+eachEvent.Id + ' has aleady been processed in AFTER_UPDATE trigger. Skipping...');
            }
        }

        // call future method to sync events to google calendar
        if(eventIdsForGoogleCalendarSync != null && eventIdsForGoogleCalendarSync.size() > 0)
        {
            GoogleApiUtilities.updateGoogleEventsFromSalesforceEvents(eventIdsForGoogleCalendarSync);
        }
    }


}