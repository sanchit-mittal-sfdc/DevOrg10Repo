public inherited sharing class ClientCredentialsFlowLwcController
{
    // Static variable to ensure the re-try mechanism is done only 1 time and not infinite
    static Boolean isRetryDoneOnce = false;

    // Set the access token
    private static Map<String, Object> authorizeUsingClientCredentialsFlow(String SFDCConfigRecName)
    {
        System.debug('authorizeUsingClientCredentialsFlow called with SFDCConfigRecName='+SFDCConfigRecName);
        
        if(String.isBlank(SFDCConfigRecName))
        {
            return new Map<String, Object>{
                                            'isSuccess' => false,
                                            'errorMessage' => 'SFDCConfigRecName is blank',
                                            'accessToken' => null,
                                            'instanceUrl' => null
                                        };
        }

        SFDC_Config__mdt clientCredentialsFlowSfdcConfig = SFDC_Config__mdt.getInstance(SFDCConfigRecName);

        System.debug('clientCredentialsFlowSfdcConfig  = '+clientCredentialsFlowSfdcConfig);

        if(clientCredentialsFlowSfdcConfig == null)
        {
            return new Map<String, Object>{
                                            'isSuccess' => false,
                                            'errorMessage' => 'SFDC_Config__mdt.getInstance(\'' +SFDCConfigRecName+'\') is null',
                                            'accessToken' => null,
                                            'instanceUrl' => null
                                        };
        }

        String client_id = clientCredentialsFlowSfdcConfig.ClientID__c;
        String client_secret = clientCredentialsFlowSfdcConfig.ClientSecret__c;
        //here we cannot make call to login.salesforce.com for access token but should be my domain very specifically
        String myDomainUrl = clientCredentialsFlowSfdcConfig.Domain_URL_of_Org_To_be_Integrated__c;

        if( String.isBlank(client_id) || String.isBlank(client_secret) || String.isBlank(myDomainUrl))
        {
            return new Map<String, Object>{
                'isSuccess' => false,
                'errorMessage' => 'Either client_id or client_secret or myDomainUrl is null in custom metadata SFDC_Config__mdt:'+SFDCConfigRecName,
                'accessToken' => null,
                'instanceUrl' => null
            };
        }
        
        
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint('https://'+ myDomainUrl +'/services/oauth2/token');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        
        String bodyString = 'grant_type=client_credentials&client_id=' +client_id + '&client_secret='+client_secret;
        System.debug('bodyString ='+bodyString);
        req.setBody(bodyString);

        HttpResponse res = new HttpResponse();
        Http h = new Http();
        try
        {
            res = h.send(req);

            if(res.getStatusCode() == 200)
            {
                System.debug('inside authorizeUsingClientCredentialsFlow, status code is '+res.getStatusCode());
                Map<String, Object> mappedResponse = (Map<String, object>)JSON.deserializeUntyped(res.getBody());
                String unEncryptedAccessToken = (String)mappedResponse.get('access_token');

                return new Map<String, Object>{
                                                'isSuccess' => true,
                                                'errorMessage' => null,
                                                'accessToken' => unEncryptedAccessToken,
                                                'instanceUrl' => (String)mappedResponse.get('instance_url') 
                                            };
                
            }
            else
            {
                System.debug('inside setAccessTokenInOauthDetailRec, status code is'+res.getStatusCode());
                throw new OAuthFlowException('Error occurred while making callout to get the access token. Status: '+res.getStatus());
            }                
        }
        catch (Exception e)
        {
            throw new AuraHandledException(e.getMessage()+e.getStackTraceString());
        }
        
        
    }




    // This is used for fetching the sObjects list from othe other org
    @AuraEnabled
    public static List<SObjectDetailsWrapper> fetchSObjectListFromLoggedIndOrg(String SFDCConfigRecName, Boolean isFetchNewAccessToken)
    {
        /**
         * So basically from when the LWC losd in conectedCallback directly, this method fetchSObjectListFromLoggedIndOrg gets called with 
         * isFetchNewAccessToken = false because we do not know whether the access token is still working or not. 
         * Also, unlike other flows, here the access token is initially setup manually in the custom metadata and not by the user since this 
         * is server to server integration where there is no user interaction at all.
         * 
         * However, if the callout fails, automatically this method is called again with isFetchNewAccessToken = TRUE so as to get the new access token.
         */

        String accessToken;
        String instanceUrl;
        Map<String, Object> resultMap; 
        SFDC_Config__mdt clientCredentialsFlowSfdcConfig;
        Boolean isVeryFirstAccessTokenSetByCodeInsteadOfManual = false;

        if(isFetchNewAccessToken )
        {
            if(!ClientCredentialsFlowLwcController.isRetryDoneOnce)
            {
                ClientCredentialsFlowLwcController.isRetryDoneOnce = true;

                resultMap =  authorizeUsingClientCredentialsFlow(SFDCConfigRecName);

                if( (Boolean)resultMap?.get('isSuccess') && resultMap.get('accessToken') != null && String.isNotBlank((String)resultMap.get('accessToken')) )
                {
                    accessToken = (String)resultMap.get('accessToken');
                    instanceUrl = (String)resultMap.get('instanceUrl');  
                }
            }
        }
        else
        {
            clientCredentialsFlowSfdcConfig = SFDC_Config__mdt.getInstance(SFDCConfigRecName);
            
            // This block is basically for lazy people who cannot even populate the custom metadata initially with the encrypted value... :D
            // this code will automatically populate on intial page load the access token
            if( String.isBlank(clientCredentialsFlowSfdcConfig.AccessToken__c) )
            {
                isVeryFirstAccessTokenSetByCodeInsteadOfManual = true;
                resultMap =  authorizeUsingClientCredentialsFlow(SFDCConfigRecName);

                if( (Boolean)resultMap?.get('isSuccess') && resultMap.get('accessToken') != null && String.isNotBlank((String)resultMap.get('accessToken')) )
                {
                    accessToken = (String)resultMap.get('accessToken');
                    instanceUrl = (String)resultMap.get('instanceUrl');                
                }
            }
            else
            {
                accessToken = CalloutHelper.doDecryption(clientCredentialsFlowSfdcConfig.AccessToken__c);
                instanceUrl = 'https://'+clientCredentialsFlowSfdcConfig.Domain_URL_of_Org_To_be_Integrated__c;
            }
        }

        if(String.isBlank(accessToken) || String.isBlank(instanceUrl))
        {
            System.debug('accessToken is null or blank');
            throw new AuraHandledException('accessToken or instanceUrl are blank');
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

                /**
                 *  There is no  REFRESH TOKEN in client credentials flow. Hence if the callout is failed justy get a new access token
                 *  by calling the same method again with parameter isFetchNewAccessToken = TRUE and also make sure retry is not 
                 * happening indefinitely but only 1 time.
                 */
                
                if(!ClientCredentialsFlowLwcController.isRetryDoneOnce)
                {
                    // try the call again if this is for the 1st time
                    return fetchSObjectListFromLoggedIndOrg(SFDCConfigRecName, true);
                }
                else
                {
                    throw new OAuthFlowException('Could not get the new access token using even after retrying for 1 time.');
                }
                
            } 
            else   
            {
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

                // Updating the custom metadata with the new access token if the fetch sobject list callout is successful and also if we have specially fetched new access token
                if(isFetchNewAccessToken || isVeryFirstAccessTokenSetByCodeInsteadOfManual)
                {   
                    String encryptedAccessToken = CalloutHelper.doEncryption(accessToken);

                    Map<String, object> customMetadataFieldsMap = new Map<String, object>{'AccessToken__c' => encryptedAccessToken};

                    CreateUpdateMetadataUtils.createUpdateMetadata('SFDC_Config__mdt.'+SFDCConfigRecName, 'SFDCConfigRecName', customMetadataFieldsMap);
                }
                

                return sObjectWrapperList;
            }
        }
        catch (Exception e)
        {
            System.debug('sm e.getMessage()='+e.getMessage());
            System.debug('sm e.getLineNumber()='+e.getLineNumber() );
            System.debug('sm e.getStackTraceString()='+e.getStackTraceString() );
            throw new AuraHandledException(e.getMessage() + ' Line Number:'+e.getLineNumber()+ ' '+ e.getStackTraceString());
        }
    }


    // This is called each time when a user selects an option from the dropdown of sobject to fetch the corresponding fields
    @AuraEnabled(cacheable=true)   
    public static List<FieldsWrapper> fetchFieldsOfSelectedObject( String sObjectApiName, String SFDCConfigRecName)
    {
        SFDC_Config__mdt clientCredentialsFlowSfdcConfig = SFDC_Config__mdt.getInstance(SFDCConfigRecName);

        if(String.isBlank(clientCredentialsFlowSfdcConfig.AccessToken__c))
        {
            throw new AuraHandledException('Access Token is blank.');
        }

        String accessToken = CalloutHelper.doDecryption(clientCredentialsFlowSfdcConfig.AccessToken__c);
        String instanceUrl = 'https://'+clientCredentialsFlowSfdcConfig.Domain_URL_of_Org_To_be_Integrated__c;


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
                throw new OAuthFlowException('Could not fetch the fields list. Status: '+res.getStatus());
            }
            else
            {
                System.debug('Response body is='+res.getBody());

                Map<String, Object> mappedResponse = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());

                if( !mappedResponse.containsKey('fields') )
                {
                    /**
                     * VVVVV IMP CONCEPT- LWC Error Handling
                     * 
                     * Only the outermost catch should throw AuraHandledException and not inner one like below one. 
                     * Otherwise it will show a generic message always: script-thrown exception sand you will not be able to debug easily
                     * 
                     * SOLUTION- for inner error use custom exception class 
                     */
                    throw new OAuthFlowException('Fields property missing inside response. Please contact your salesforce admin.');
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
        catch(OAuthFlowException e)
        {
            throw new AuraHandledException(e.getMessage());
        }
        catch (Exception e)
        {
            throw new AuraHandledException(e.getMessage());
        }
    }


    // This is used for fetching records of selected object and fields
    @AuraEnabled(cacheable=true)
    public static List<Object> fetchRecords(String sObjectApiName, String commaSeparatedFieldsList, String soqlQueryClauseVal, String SFDCConfigRecName)
    {
        SFDC_Config__mdt clientCredentialsFlowSfdcConfig = SFDC_Config__mdt.getInstance(SFDCConfigRecName);
        String accessToken = CalloutHelper.doDecryption(clientCredentialsFlowSfdcConfig.AccessToken__c);
        String instanceUrl = 'https://'+clientCredentialsFlowSfdcConfig.Domain_URL_of_Org_To_be_Integrated__c;

        if( String.isBlank(sObjectApiName) || String.isBlank(commaSeparatedFieldsList) || String.isBlank(accessToken) || String.isBlank(instanceUrl) )
        {
            return null;
        }
    
        //https://sanchitmittal-dev-ed.my.salesforce.com/services/data/v60.0/query/?q=SELECT+Id,Name,Type,Website,Phone+FROM+Account
        HttpRequest req = new HttpRequest();

        String soqlQuery = 'SELECT '+commaSeparatedFieldsList+' FROM '+sObjectApiName;

        if(String.isNotBlank(soqlQueryClauseVal))
        {
            soqlQuery = soqlQuery + ' ' + soqlQueryClauseVal;
        }

        System.debug('soqlQueryClauseVal = '+soqlQueryClauseVal);
        System.debug('soqlQuery = '+soqlQuery);

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
                /**
                 * VVVVV IMP CONCEPT- LWC Error Handling
                 * 
                 * Only the outermost catch should throw AuraHandledException and not inner one like below one. 
                 * Otherwise it will show a generic message always: script-thrown exception sand you will not be able to debug easily
                 * 
                 * SOLUTION- for inner error use custom exception class 
                 */
                throw new OAuthFlowException('Could not fetch the records. Status: '+res.getStatus());
            }
            else
            {
                System.debug('Response body is='+res.getBody());

                Map<String, Object> mappedResponse = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());

                if( !mappedResponse.containsKey('records') )
                {
                    /**
                     * VVVVV IMP CONCEPT- LWC Error Handling
                     * 
                     * Only the outermost catch should throw AuraHandledException and not inner one like below one. 
                     * Otherwise it will show a generic message always: script-thrown exception sand you will not be able to debug easily
                     * 
                     * SOLUTION- for inner error use custom exception class 
                     */
                    throw new OAuthFlowException('records property missing inside response. Please contact your salesforce admin.');
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
            System.debug('sm e.getMessage()='+e.getMessage());
            System.debug('sm e.getLineNumber()='+e.getLineNumber() );
            System.debug('sm e.getStackTraceString()='+e.getStackTraceString() );
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

    // Custom Exception class
    public class OAuthFlowException extends Exception {}
}