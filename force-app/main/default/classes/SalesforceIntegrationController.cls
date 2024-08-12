public inherited sharing class SalesforceIntegrationController
{
    /*
        This is method is called on page load to fetch the status as well as the accounts from corresponding org in case connection is working
    */
    @AuraEnabled
    public static List<SfdcOrgsResponseWrapper> handlePageLoad()
    {
        System.debug('handlePageLoad called');
        // SFDC_Config__mdt is a custom metadata type, which is used to store the credentials of the orgs for which we need to make the callouts.
        List<SfdcOrgsResponseWrapper> orgsResponseWrapperList = new List<SfdcOrgsResponseWrapper>();
        
        List<SFDC_Config__mdt> sfOrgsList = [SELECT Id, DeveloperName, MasterLabel, Label, AccessToken__c, Access_Token_URL__c, Auth_Code_URL__c, ClientID__c, 
                                                    ClientSecret__c, Environment__c, Expires_at_Time__c, Expires_in__c, Instance_URL__c, Page_Name__c, Refresh_Token__c, 
                                                    Scope__c, Issued_at__c, Description__c, Active__c, Org_Type__c, Method_Type__c, Allowed_Operations_Details__c, Refresh_Token_URL__c, Domain_URL_of_Org_To_be_Integrated__c
                                            FROM SFDC_Config__mdt
                                            WHERE Active__c = true AND Org_Type__c = 'Salesforce'];


        for( SFDC_Config__mdt sfdcConfig : sfOrgsList )
        {
            try
            {
                orgsResponseWrapperList.add( scanAndHandleSfdcOrg(sfdcConfig) );
            }
            catch (Exception e)
            {
                throw new AuraHandledException(e.getMessage());
            }
        }
        System.debug('orgsResponseWrapperList ='+orgsResponseWrapperList);
        return orgsResponseWrapperList;
    }


    /* ##################################################################################################################################
        This method accepts the metadata rec of each SF org and does the following:

        1) If the access token is expired, refresh token is used to get a new access token.

        2) If either the refresh token is expired or the Accesss Token fiekd is blank, then 
           sets the isConnected as FALSE. hence the user will have to re-authorize from 
           beginning using VF pgae oAuth 2.0 Web Server Flow.

        3) If the Access token is working fine (checks by making a Fetch Accounts call to 
           corresponding SF org), then it returns the accounts so that no extra callout is 
           made for fetching accounts of this org 

    ##################################################################################################################################*/
    public static SfdcOrgsResponseWrapper scanAndHandleSfdcOrg( SFDC_Config__mdt sfdcConfig)
    {
        Boolean isConnectionWorking = false;

        // If access token is blank then simply return a response specifying that there's no active connection
        if( String.isBlank(sfdcConfig.AccessToken__c) )
        {
            return new SfdcOrgsResponseWrapper( sfdcConfig.DeveloperName, isConnectionWorking, null, '', 'The access token is missing. Please proceed with authorization.' );
        }


        /* ##################################################################################################################################
            V.IMP Logic
            Here we'll deserialize the details present in field "Allowed Operations Details"

            Sample :[
                        {
                            "useThisForCheckingAccessToken":"true",
                            "operationType":"Fetch Accounts",
                            "methodType":"GET",
                            "endpointUrl":"/services/data/v60.0/query/?q=SELECT+Id,Name,Type,Website,Phone+FROM+Account",
                            "body":"",
                            "headers":"Accept=application/json@Authorization=Bearer@",
                            "sObjectName":"Account",
                            "labelFieldMap":"Account Name:Name@Account Type:Type@Website:Website@Phone:Phone"
                        },

                        {
                            "useThisForCheckingAccessToken":"false",
                            "operationType":"Create Account",
                            "methodType":"POST",
                            "endpointUrl":"/services/data/v60.0/sobjects/Account",
                            "body":"",
                            "headers":"Content-Type=application/json@Accept=application/json@Authorization=Bearer@",
                            "sObjectName":"Account",
                            "labelFieldMap":"Account Name:Name@Account Type:Type@Website:Website@Phone:Phone"
                        }
                    ]
          ##################################################################################################################################              
        */    
        List<Object> allowedOperationsDetails = (List<Object>)JSON.deserializeUntyped( sfdcConfig.Allowed_Operations_Details__c );

        for(Object operation: allowedOperationsDetails)
        {
            Map<String, Object> allowedOperation = (Map<String, object>)operation;
            System.debug('allowedOperation: '+ allowedOperation); 

            HttpResponse defaultCalloutResponse;
            HttpResponse refreshTokenCalloutResponse;

            if( (String)allowedOperation.get('useThisForCheckingAccessToken') == 'true' )
            {
                //#################################### STEP 1: Default callout- to check if access token is still working ##############################
                String methodTypeDefault = (String)allowedOperation.get('methodType');
                //String endpointUrlDefault = sfdcConfig.Instance_URL__c + EncodingUtil.urlEncode( (String)allowedOperation.get('endpointUrl'), 'UTF-8' );
                String endpointUrlDefault = sfdcConfig.Instance_URL__c + (String)allowedOperation.get('endpointUrl');

                String bodyDefault = methodTypeDefault.equalsIgnoreCase('GET')  ? null : (String)allowedOperation.get('body');

                Map<String, String> headersDefault = new Map<String, String>();
                
                for(String headerKeyValPair : ((String)allowedOperation.get('headers')).split('@') )
                {
                    String headerKey = headerKeyValPair.split('=')[0];
                    String headerVal = headerKeyValPair.split('=')[1];

                    if( headerKey.equalsIgnoreCase('Authorization') )
                    {
                        headersDefault.put( headerKey, headerVal + ' ' + sfdcConfig.AccessToken__c);
                    }
                    else
                    {
                        headersDefault.put( headerKey, headerVal);
                    }
                }

                defaultCalloutResponse = doCalloutAndReturnResponse(methodTypeDefault, endpointUrlDefault, bodyDefault, headersDefault );



                // ################################### STEP 2: If defaultCalloutResponse ==  null or res.getStatusCode() != 200/201 then it means we need to further check if the refresh token is still working or not
                if( defaultCalloutResponse == null || !(defaultCalloutResponse.getStatusCode() == 200 || defaultCalloutResponse.getStatusCode() == 201) )
                {
                     String body = 'grant_type=refresh_token&client_id=' + sfdcConfig.ClientID__c + '&client_secret=' + sfdcConfig.ClientSecret__c + '&refresh_token='+sfdcConfig.Refresh_Token__c;

                     Map<String, String> headers = new Map<String, String>();
                     headers.put('Accept', 'application/json');

                     //################################### STEP 3:  Check if the refresh token is working or not ###################################
                     refreshTokenCalloutResponse = doCalloutAndReturnResponse( 'POST', sfdcConfig.Instance_URL__c + sfdcConfig.Refresh_Token_URL__c, body, headers);

                     // ################################### STEP 4: if refreshTokenCalloutResponse ==  null or res.getStatusCode() != 200/201 then it means we need to RE-INITIATE THE Authorizatuion process from beginning using VF Page  and will be sending this info to the LWC using wrapper
                     if( refreshTokenCalloutResponse == null || !(refreshTokenCalloutResponse.getStatusCode() == 200 || refreshTokenCalloutResponse.getStatusCode() == 201) )
                     {
                        isConnectionWorking = false;
                        Datetime dt = system.now();
                        return new SfdcOrgsResponseWrapper( sfdcConfig.DeveloperName, isConnectionWorking, null, '', 'The access token could not be refreshed using the existing refresh token on '+dt.format('dd-MMM-yyyy') +' at '+ dt.format('h:mm a') +'. Hence, please re-authorize.');
                     }
                     else//################################### STEP 5:  else it means refresh token worked successfully to get the new access token. Hence we can now update the access token in custom metadata. BUT WE WONT BE making a callout agin to fetch the data . lazy approach- If the user want he can now click thge button on LWC to fetch the data
                     {
                        isConnectionWorking = true;

                        Map<String, Object> refreshTokenCalloutResponseMap = (Map<String, Object>)JSON.deserializeUntyped(refreshTokenCalloutResponse.getBody());

                        String refreshedAccessToken           = (String)refreshTokenCalloutResponseMap.get('access_token');
                        DateTime refreshedAccessTokenIssuedAt = System.now();

                        Map<String, Object> fieldWithValuesMap = new Map<String, Object>();
                        fieldWithValuesMap.put('AccessToken__c', refreshedAccessToken);
                        fieldWithValuesMap.put('Issued_at__c', refreshedAccessTokenIssuedAt);

                        Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
                        customMetadata.fullName = 'SFDC_Config__mdt.' + sfdcConfig.DeveloperName;
                        customMetadata.label = sfdcConfig.Label;

                        for( String eachKey : fieldWithValuesMap.keySet())
                        {
                            Metadata.CustomMetadataValue customField = new Metadata.CustomMetadataValue();
                            customField.field = eachKey;
                            customField.value = fieldWithValuesMap.get(eachKey);
                            customMetadata.values.add(customField);
                        }

                        Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
                        mdContainer.addMetadata(customMetadata);
                        CreateUpdateMetadataUtils callback = new CreateUpdateMetadataUtils();

                        try {
                            Id jobId = Metadata.Operations.enqueueDeployment(mdContainer, callback);
                            System.debug('Metadata deployment time='+system.now() + ' and job ID = '+jobId);
                        } catch (Exception e) {
                            System.debug('Deployment failed to enqueue: ' + e.getMessage());
                        }
                        Datetime dt = system.now();
                        return new SfdcOrgsResponseWrapper( sfdcConfig.DeveloperName, isConnectionWorking, null, '', 'A new access token was fetched successfully using the existing refresh token on '+dt.format('dd-MMM-yyyy') +' at '+ dt.format('h:mm a') +'.');
                     }
                }
                else//################################### STEP 6:  else it means Existing Access Token worked successfully to hit the default callout to this org. Hence, we can make use of fetched data and return it to client in case the end user needs it then there wont be any need of making a callout.
                {
                    isConnectionWorking = true;

                    System.debug('In Step 6: defaultCalloutResponse.getBody() = '+defaultCalloutResponse.getBody());

                    Map<String, Object> defaultCalloutResponseMap =  (Map<String, Object>)JSON.deserializeUntyped( defaultCalloutResponse.getBody() );
                    List<SObject> defaultRecords =  (List<SObject>)JSON.deserialize( JSON.serialize(defaultCalloutResponseMap.get('records')), List<SObject>.class);

                    String labelFieldMap = (String)allowedOperation.get('labelFieldMap');    
                    
                    return new SfdcOrgsResponseWrapper( sfdcConfig.DeveloperName, isConnectionWorking, defaultRecords, labelFieldMap, 'The access token, fetched on ' + sfdcConfig.Issued_at__c.format('dd-MMM-yyyy') +' at '+ sfdcConfig.Issued_at__c.format('h:mm a') + ', is valid and working.');
                }

            } 
        }
        return new SfdcOrgsResponseWrapper( sfdcConfig.DeveloperName, isConnectionWorking, null, '','No configuration was found for checking the connection in Allowed Operations Details. Please contact your administrator.' );
    }

    public static HttpResponse doCalloutAndReturnResponse( String methodType, String endpointUrl, String body, Map<String, String> headers )
    {
        System.debug('Inside doCalloutAndReturnResponse');
        System.debug('methodType = '+methodType);
        System.debug('endpointUrl = '+endpointUrl);
        System.debug('body = '+body);
        System.debug('headers = '+headers);


        HttpRequest req = new HttpRequest();
        
        req.setMethod(methodType);

        if( methodType.equalsIgnoreCase('POST') || methodType.equalsIgnoreCase('PATCH') )
        {
            req.setBody(body);
        }

        for( String headerKey : headers.keySet() )
        {
            req.setHeader(headerKey, headers.get(headerKey));
        }


        req.setEndpoint(endpointUrl);

        HttpResponse res = new HttpResponse();
        Http h = new Http();
        
        try {
            
            res = h.send(req);
            System.debug('res.getStatusCode() = '+res.getStatusCode());
            System.debug('res.getBody() = '+res.getBody());
            return res;
        }
        catch (Exception e)
        {
            System.debug('Exception occurred: '+e.getMessage());  
            return null;  
        }
    }
}