public inherited sharing class UserAgentFlowController
{
    @AuraEnabled(cacheable=true)
    public static SFDC_Config__mdt getUserAgentFlowGeneric()
    {
        return SFDC_Config__mdt.getInstance('UserAgentFlowGeneric');
    }


    // This is used for fetching the sObjects list from othe other org
    @AuraEnabled
    public static List<SObjectDetailsWrapper> fetchSObjectListFromLoggedIndOrg(String accessToken, String instanceUrl)
    {
        // if access token is blank do nothing
        if( String.isBlank(accessToken) || String.isBlank(instanceUrl))
        {
            return null;
        }

        List<SObjectDetailsWrapper> sObjectWrapperList = new List<SObjectDetailsWrapper>();

        // else make a callout to get the sobjects list
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint( instanceUrl + '/services/data/v58.0/sobjects');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + accessToken);

        HttpResponse res = new HttpResponse();

        Http h = new Http();

        try
        {
            res = h.send(req);

            if( res.getStatusCode() != 200 )
            {
                throw new AuraHandledException('Could not fetch SObject list. Status: '+res.getStatus());
            } 
            else   
            {
                //JSON.serialize( 
                Map<String, Object> mappedResponse = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());

                for( Object eachSObject : (List<Object>)mappedResponse.get('sobjects') )
                {
                    System.System.debug('eachSObject='+eachSObject);
                    Map<String, Object> eachSobjectMap = (Map<String, Object>)eachSObject;

                    Boolean queryable = (Boolean)eachSobjectMap.get('queryable');
                    Boolean triggerable = (Boolean)eachSobjectMap.get('triggerable');
                    String sObjectLabel = (String)eachSobjectMap.get('label');
                    String sObjectApiName = (String)eachSobjectMap.get('name');

                    if( queryable && triggerable)
                    {
                        sObjectWrapperList.add( new SObjectDetailsWrapper(sObjectLabel, sObjectApiName));
                    }
                }
                System.debug('sObjectWrapperList size='+sObjectWrapperList.size());
                System.debug('sObjectWrapperList ='+sObjectWrapperList);
                return sObjectWrapperList;
            }
        }
        catch (Exception e)
        {
            throw new AuraHandledException(e.getMessage());
        }
    }


    // This is called each time when a user selects an option from the dropdown of sobject to fetch the corresponding fields
    @AuraEnabled(cacheable=true)   
    public static List<FieldsWrapper> fetchFieldsOfSelectedObject( String sObjectApiName, String accessToken, String instanceUrl)
    {
        if( String.isBlank(sObjectApiName) || String.isBlank(accessToken) || String.isBlank(instanceUrl) )
        {
            return null;
        }

        List<FieldsWrapper> fieldsWrapperList = new List<FieldsWrapper>();
        
        // https://sanchitmittal-dev-ed.my.salesforce.com/services/data/v61.0/sobjects/objPd__c/describe

        HttpRequest req = new HttpRequest();
        req.setEndpoint(instanceUrl + '/services/data/v58.0/sobjects/' + sObjectApiName + '/describe'); 
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Authorization', 'Bearer '+accessToken);

        Http h = new Http();
        HttpResponse res = new HttpResponse();
        
        try
        {
            res = h.send(req);

            if(res.getStatusCode()!= 200 )
            {
                throw new AuraHandledException('Could not fetch the fields list. Status: '+res.getStatus());
            }
            else
            {
                System.debug('Response body is='+res.getBody());

                Map<String, Object> mappedResponse = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());

                if( !mappedResponse.containsKey('fields') )
                {
                    throw new AuraHandledException('Fields property missing inside response. Please contact your salesforce admin.');
                }

                for(Object eachFieldObj : (List<Object>)mappedResponse.get('fields'))
                {
                    Map<String, Object> eachFieldDetails = (Map<String, Object>)eachFieldObj;
                    String fieldLabel = (String)eachFieldDetails.get('label');
                    String fieldApiName = (String)eachFieldDetails.get('name');

                    fieldsWrapperList.add( new FieldsWrapper(fieldLabel, fieldApiName) );
                }

                return fieldsWrapperList;
            }
        }
        catch (Exception e)
        {
            throw new AuraHandledException(e.getMessage());
        }
    }


    // This is used for fetching records of selected object and fields
    @AuraEnabled(cacheable=true)
    public static List<Object> fetchRecords(String sObjectApiName, String commaSeparatedFieldsList, String accessToken, String instanceUrl)
    {
        if( String.isBlank(sObjectApiName) || String.isBlank(commaSeparatedFieldsList) || String.isBlank(accessToken) || String.isBlank(instanceUrl) )
        {
            return null;
        }
    
        //https://sanchitmittal-dev-ed.my.salesforce.com/services/data/v60.0/query/?q=SELECT+Id,Name,Type,Website,Phone+FROM+Account
        HttpRequest req = new HttpRequest();

        String soqlQuery = 'SELECT '+commaSeparatedFieldsList+' FROM '+sObjectApiName;

        String endPointUrl = instanceUrl + '/services/data/v58.0/query/?q=' + EncodingUtil.urlEncode(soqlQuery, 'UTF-8');
        System.debug('endPointUrl is ============ '+endPointUrl);
        
        req.setEndpoint(endPointUrl); 
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Authorization', 'Bearer '+accessToken);

        Http h = new Http();
        HttpResponse res = new HttpResponse();
        
        try
        {
            res = h.send(req);

            if(res.getStatusCode()!= 200 )
            {
                throw new AuraHandledException('Could not fetch the records. Status: '+res.getStatus());
            }
            else
            {
                System.debug('Response body is='+res.getBody());

                Map<String, Object> mappedResponse = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());

                if( !mappedResponse.containsKey('records') )
                {
                    throw new AuraHandledException('records property missing inside response. Please contact your salesforce admin.');
                }

                for(Object eachRecObj : (List<Object>)mappedResponse.get('records'))
                {
                    Map<String, Object> eachRecDetails = (Map<String, Object>)eachRecObj;
                    /*
                    String fieldLabel = (String)eachFieldDetails.get('label');
                    String fieldApiName = (String)eachFieldDetails.get('name');

                    fieldsWrapperList.add( new FieldsWrapper(fieldLabel, fieldApiName) );*/
                }

                return (List<Object>)mappedResponse.get('records');
            }
        }
        catch (Exception e)
        {
            throw new AuraHandledException(e.getMessage());
        }
    }








    // Wrapper classes

    // Wrapper class for SOBJECTS
    public class SObjectDetailsWrapper
    {
        @AuraEnabled
        public String sObjectLabel {
            get{
                return sObjectLabel;
            } 
            set{
                sObjectLabel = value;
            }
        }


        @AuraEnabled
        public String sObjectApiName {
            get{
                return sObjectApiName;
            } 
            set{
                sObjectApiName = value;
            }
        }

        public SObjectDetailsWrapper( String sObjectLabel, String sObjectApiName)
        {
            this.sObjectLabel = sObjectLabel;
            this.sObjectApiName = sObjectApiName;
        }
    }


    // Wrapper class for FIELDS
    public class FieldsWrapper
    {
        @AuraEnabled
        public String fieldLabel {
            get{
                return fieldLabel;
            }
            set{
                fieldLabel = value;
            }
        }

        @AuraEnabled
        public String fieldApiName {
            get{
                return fieldApiName;
            }
            set{
                fieldApiName = value;
            }
        }

        // constructor
        public FieldsWrapper(String fieldLabel, String fieldApiName)
        {
            this.fieldLabel = fieldLabel;
            this.fieldApiName = fieldApiName;
        }
        
    }


}