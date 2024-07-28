public with sharing class Batch_ZendeskIntegration implements Database.Batchable<sObject>, Database.AllowsCallouts, Schedulable
{
    public Database.QueryLocator start (Database.BatchableContext bc)
    {
        String caseQuery = 'SELECT Id, Subject, Priority, Description, Zendesk_Id__c FROM Case WHERE Create_on_Zendesk__c = TRUE AND Zendesk_Id__c = null';

        return Database.getQueryLocator(caseQuery);
    }

    public void execute(Database.BatchableContext bc, List<Case> scope)
    {
        if(schema.SObjectType.Case.isUpdateable() && schema.SObjectType.Case.fields.Zendesk_Id__c.isUpdateable())
        {
            List<Case> casesToUpdate = new List<Case>();
            for(Case c : scope)
            {
                String zendeskCaseID = createOnZendesk(c);
                casesToUpdate.add( new Case(Id = c.id, Zendesk_Id__c = zendeskCaseID) );
            }
            if(casesToUpdate.size() > 0)
            {
                SObjectAccessDecision decision = Security.stripInaccessible(AccessType.Updatable, casesToUpdate);
                Database.update( decision.getRecords(), false);
            }
        }
    }

    public void execute(SchedulableContext sc) 
    {
        Database.executeBatch( new Batch_ZendeskIntegration(), 10);
    }

    public void finish(Database.BatchableContext bc)
    {
        
    }

    public static String createOnZendesk(Case c)
    {
        Zendesk_Integration__mdt calloutDetails = Zendesk_Integration__mdt.getInstance('TicketCreateRequest');
        
        if(calloutDetails == null)
        {
            return null;
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint(calloutDetails.Endpoint_URL__c);
        req.setMethod(calloutDetails.Method_Type__c);
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');

        String emailAdd                 = calloutDetails.Email__c;
        String apiToken                 = calloutDetails.API_Token__c;
        String authDetailsToBeEncoded   = emailAdd + '/token:' + apiToken;

        String base64EncodedAuthDetails = EncodingUtil.base64Encode( Blob.valueOf(authDetailsToBeEncoded) );
        req.setHeader('Authorization', 'Basic ' + base64EncodedAuthDetails);

        String payload=		'{'+
		'    "ticket": {'+
		'        "comment": {'+
		'            "body": "' + c.Description + '"'+
		'        },'+
		'        "priority": "' + c.Priority.toLowerCase() +'",'+
		'        "subject": "'+ c.Subject +'"'+
		'    }'+
		'}';

        req.setBody(payload);

        Http h = new Http();
        HttpResponse res;

        try
        {
            res = h.send(req);    
        }
        catch(CalloutException e)
        {

            System.debug('CalloutException while callout '+ e.getMessage());
            return null;
        } 
        catch (Exception e) {
            System.debug('Exception while callout '+ e.getMessage());
            return null;   
        }

        System.debug('Response body is='+res.getBody());
        System.debug('Status code is='+res.getStatusCode());

        if( res.getStatusCode() == 201 || res.getStatusCode() == 200) 
        {
            System.debug('callout was successfull');

            String zendeskCaseID;
            Map<String, Object> mappedResponse = (Map<String, Object>)JSON.deserializeUntyped( res.getBody());
            //System.debug('sm resp id='+mappedResponse.get('id'));
            
            if( mappedResponse.get('ticket') != null)
            {
                Map<String, Object> ticketDetailsMap = (Map<String, Object>)mappedResponse.get('ticket');
                return String.valueOf( ticketDetailsMap.get('id') );
            }
            return null;
        }
        else {
            System.debug('callout got failed');
            return null;
        }
    }
}