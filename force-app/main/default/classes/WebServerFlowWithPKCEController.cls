public inherited sharing class WebServerFlowWithPKCEController
{
    // to return the SFDC Config custom metadata record
    @AuraEnabled(cacheable=true)
    public static SFDC_Config__mdt getPKCEFlowGeneric()
    {
        return SFDC_Config__mdt.getInstance('PKCEFlowGeneric');
    }

    // To fetch the current org domain url
    @AuraEnabled(cacheable=true)
    public static string fetchOrgDomainUrl(){
        try {
           return System.URL.getOrgDomainURL().toExternalForm(); 
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }


    // Set the access token
    @AuraEnabled
    public static Map<String, Object> setAccessTokenInOauthDetailRec(String code, String stateFromAuthServer)
    {
        if(String.isBlank(code) || String.isBlank(stateFromAuthServer))
        {
            throw new AuraHandledException('code or stateFromAuthServer is blank');
        }

        OAuthFlowDetails__c oAuthFlowDetailsRec = WebServerFlowWithPKCEController.checkAndReturnCurrentUserOauthRec_Internal('WebServerFlowWithPKCE');
        System.debug('oAuthFlowDetailsRec  = '+oAuthFlowDetailsRec);



        String client_id = SFDC_Config__mdt.getInstance('PKCEFlowGeneric').ClientID__c;
        String client_secret = SFDC_Config__mdt.getInstance('PKCEFlowGeneric').ClientSecret__c;
        String redirectUri = 'https://wonton-deploy-6437-dev-ed.scratch.lightning.force.com/lightning/n/OAuth_2_0_Web_Server_Flow_WITH_PKCE';
        
        
        if(oAuthFlowDetailsRec != null && String.isNotBlank(oAuthFlowDetailsRec.Code_Verifier__c) && String.isNotBlank(oAuthFlowDetailsRec.State__c))
        {
            System.debug('stateFromAuthServer = '+stateFromAuthServer);
            System.debug('oAuthFlowDetailsRec.State__c = '+oAuthFlowDetailsRec.State__c);

            if(!stateFromAuthServer.equalsIgnoreCase(oAuthFlowDetailsRec.State__c))
            {
                System.debug('State from AuthServer is not matching');
                throw new AuraHandledException('State from AuthServer is not matching');
            }
            System.debug('State from AuthServer is matching');
            HttpRequest req = new HttpRequest();
            req.setMethod('POST');
            req.setEndpoint('https://login.salesforce.com/services/oauth2/token');
            req.setHeader('Accept', 'application/json');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            
            String bodyString = 'grant_type=authorization_code&code='+code+'&client_id=' +client_id + '&client_secret='+client_secret+'&code_verifier='+oAuthFlowDetailsRec.Code_Verifier__c+'&redirect_uri='+redirectUri;
            // WITHOUT PKCE: String bodyString = 'grant_type=authorization_code&code='+code+'&client_id=' +client_id + '&client_secret='+client_secret+'&redirect_uri='+redirectUri;
            System.debug('bodyString ='+bodyString);
            req.setBody(bodyString);

            HttpResponse res = new HttpResponse();
            Http h = new Http();
            try
            {
                res = h.send(req);

                if(res.getStatusCode() == 200)
                {
                    System.debug('inside setAccessTokenInOauthDetailRec, status code is '+res.getStatusCode());
                    Map<String, Object> mappedResponse = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());

                    String unEncryptedAccessToken = (String)mappedResponse.get('access_token');
                    String encryptedAccessToken = CalloutHelper.doEncryption(unEncryptedAccessToken);

                    oAuthFlowDetailsRec.Access_Token__c = encryptedAccessToken;
                    oAuthFlowDetailsRec.Refresh_Token__c = CalloutHelper.doEncryption( (String)mappedResponse.get('refresh_token') );
                    oAuthFlowDetailsRec.Instance_URL__c = (String)mappedResponse.get('instance_url');

                    System.debug('oAuthFlowDetailsRec to be updated = '+oAuthFlowDetailsRec);
                    update oAuthFlowDetailsRec;
                    return new Map<String, Object>{
                        'isSuccess' => true, 
                        'instanceUrl' => (String)mappedResponse.get('instance_url'),
                        'oauthFlowDetailRecId' => oAuthFlowDetailsRec.Id
                    };
                }
                else
                {
                    System.debug('inside setAccessTokenInOauthDetailRec, status code is'+res.getStatusCode());
                    /**
                     * VVVVV IMP CONCEPT- LWC Error Handling
                     * 
                     * Only the outermost catch should throw AuraHandledException and not inner one like below one. 
                     * Otherwise it will show a generic message always: script-thrown exception sand you will not be able to debug easily
                     * 
                     * SOLUTION- for inner error use custom exception class 
                     */
                    throw new OAuthFlowException('Error occurred while making callout to get the access token. Status: '+res.getStatus());
                }                
            }
            catch (Exception e)
            {
                throw new AuraHandledException(e.getMessage()+e.getStackTraceString());
            }
        }
        else
        {
            throw new AuraHandledException('Either Code_Verifier__c/State__c or oAuthFlowDetails record is missing');
        }
        
    }



    // This returns the code_challenge and code_verifier required for OAuth 2.0 Web Server Flow with PKCE i.e PROOF KEY FOR CODE EXCHANGE
    @AuraEnabled
    public static Map<String, Object> getPKCEDetails()
    {
        try
        {
            String code_verifier = System.UUID.randomUUID().toString();

            Blob code_challenge_blob = Crypto.generateDigest('SHA-256', Blob.valueOf(code_verifier));

            String code_challenge = EncodingUtil.Base64Encode(code_challenge_blob)
                                                                .replace('/', '_')
                                                                .replace('+', '-')
                                                                .replaceAll('=+$', '');

            return new Map<String, Object> {'code_verifier' => code_verifier, 'code_challenge' => code_challenge };
        }
        catch (Exception e)
        {
            throw new AuraHandledException(e.getMessage());
        }
    }


    @AuraEnabled
    public static string createOauthFlowDetailRec(String applicationName)
    {
        try
        {
            Map<String, Object> pkceMap = WebServerFlowWithPKCEController.getPKCEDetails();


            OAuthFlowDetails__c newOauthFlowDetail = new OAuthFlowDetails__c();
            newOauthFlowDetail.Code_Verifier__c = (String)pkceMap.get('code_verifier');
            newOauthFlowDetail.Code_Challenge__c = (String)pkceMap.get('code_challenge');
            newOauthFlowDetail.State__c = EncodingUtil.Base64Encode(Blob.valueOf(System.UUID.randomUUID().toString()));
            newOauthFlowDetail.Application__c = applicationName;
            newOauthFlowDetail.User__c = UserInfo.getUserId();

            Insert newOauthFlowDetail;

            return newOauthFlowDetail.Id;
        }
        catch (Exception e)
        {
            throw new AuraHandledException(e.getMessage());
        }
    }



    /**
     * This method check and returns the records of OAuthFlowDetails__c custom object if found on basis of user and application field
     */
    @AuraEnabled
    public static Map<String, Object> checkAndReturnCurrentUserOauthRec(String applicationName)
    {
        try
        {
            Id currentUserId = UserInfo.getUserId();
            List<OAuthFlowDetails__c> oauthDetailsList = [SELECT Id, Name, CreatedDate, CreatedById, LastModifiedDate, User__c, Code_Challenge__c, Code_Verifier__c, State__c, Access_Token__c, Refresh_Token__c, Instance_URL__c, Application__c 
                                                          FROM OAuthFlowDetails__c
                                                          WHERE User__c = :currentUserId AND Application__c = :applicationName];

            
            if(oauthDetailsList.size() == 0)
            {
                return null;
            }
            if(oauthDetailsList.size() == 1)
            {
                Map<String, Object> oAuthDetailsMap = new Map<String, Object>();
                oAuthDetailsMap.put('recId', oauthDetailsList[0].Id);
                oAuthDetailsMap.put('instanceUrl', oauthDetailsList[0].Instance_URL__c);
                oAuthDetailsMap.put('isAccessTokenPresent', String.isNotBlank(oauthDetailsList[0].Access_Token__c)? true : false);
                oAuthDetailsMap.put('isRefreshTokenPresent', String.isNotBlank(oauthDetailsList[0].Refresh_Token__c)? true : false);
                return oAuthDetailsMap;
            }
            else
            {
                /**
                 * VVVVV IMP CONCEPT- LWC Error Handling
                 * 
                 * Only the outermost catch should throw AuraHandledException and not inner one like below one. 
                 * Otherwise it will show a generic message always: script-thrown exception sand you will not be able to debug easily
                 * 
                 * SOLUTION- for inner error use custom exception class 
                 */
                throw new OAuthFlowException('More than one record found for the same user and application. Please contact your admin to delete the extra record');
            }
        }
        catch (Exception e)
        {
            throw new AuraHandledException(e.getMessage());
        }
    }


    public static OAuthFlowDetails__c checkAndReturnCurrentUserOauthRec_Internal(String applicationName)
    {
        try
        {
            Id currentUserId = UserInfo.getUserId();
            List<OAuthFlowDetails__c> oauthDetailsList = [SELECT Id, Name, CreatedDate, CreatedById, LastModifiedDate, User__c, Code_Challenge__c, Code_Verifier__c, State__c, Access_Token__c, Refresh_Token__c, Instance_URL__c, Application__c 
                                                          FROM OAuthFlowDetails__c
                                                          WHERE User__c = :currentUserId AND Application__c = :applicationName];

            
            if(oauthDetailsList.size() == 0)
            {
                return null;
            }
            if(oauthDetailsList.size() == 1)
            {
                return oauthDetailsList[0];
            }
            else
            {
                /**
                 * VVVVV IMP CONCEPT- LWC Error Handling
                 * 
                 * Only the outermost catch should throw AuraHandledException and not inner one like below one. 
                 * Otherwise it will show a generic message always: script-thrown exception sand you will not be able to debug easily
                 * 
                 * SOLUTION- for inner error use custom exception class 
                 */
                throw new OAuthFlowException('More than one record found for the same user and application. Please contact your admin to delete the extra record');
            }
        }
        catch (Exception e)
        {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // This is used for fetching the sObjects list from othe other org
    @AuraEnabled
    public static List<SObjectDetailsWrapper> fetchSObjectListFromLoggedIndOrg(String instanceUrl, String newAccessTokenUsingRefreshToken)
    {
        OAuthFlowDetails__c oAuthFlowDetailsRec = checkAndReturnCurrentUserOauthRec_Internal('WebServerFlowWithPKCE');
        String accessToken = String.isBlank(newAccessTokenUsingRefreshToken) ? CalloutHelper.doDecryption(oAuthFlowDetailsRec.Access_Token__c) : newAccessTokenUsingRefreshToken;

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

                /**
                 *  USE REFRESH TOKEN to get the new access token if the callout is failed.
                 *  If the problem persists, then you have to ask the user to "Reload" the org to get the session details.
                 */
                
                 if(String.isBlank(newAccessTokenUsingRefreshToken))
                 {
                    try
                    {
                        // re-try only only one time which we will know by this condition i..e if newaccesstokenusingrefreshtoken is blank
                        String newAccessToken = CalloutHelper.getSFAccessTokenUsingRefreshToken(
                                                                                CalloutHelper.doDecryption(oAuthFlowDetailsRec.Refresh_Token__c), 
                                                                                oAuthFlowDetailsRec.Instance_URL__c,
                                                                                SFDC_Config__mdt.getInstance('PKCEFlowGeneric').ClientID__c,
                                                                                SFDC_Config__mdt.getInstance('PKCEFlowGeneric').ClientSecret__c);

                        if(String.isNotBlank(newAccessToken))
                        {
                            // try the call again
                            return fetchSObjectListFromLoggedIndOrg(instanceUrl, newAccessToken);
                        }
                        else
                        {
                            throw new OAuthFlowException('Could not get the new access token using refresh token');
                        }
                    }
                    catch(Exception e)
                    {
                        throw new OAuthFlowException(e.getMessage());
                    }
                    
                 }
                 else
                 {
                     // if even after retrying there's an issue then user has to relogin again
                     throw new OAuthFlowException('Please logout to login again since we could not authorize you even with the refresh token.');
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

                // update the new access token if newAccessTokenUsingRefreshToken is passed and the callout is successful
                if( String.isNotBlank(newAccessTokenUsingRefreshToken) )
                {
                    // update the access token in the oAuth Flow Record
                    oAuthFlowDetailsRec.Access_Token__c = CalloutHelper.doEncryption(newAccessTokenUsingRefreshToken);
                    update oAuthFlowDetailsRec;
                    System.debug('oAuthFlowDetailsRec after updating the access token :'+oAuthFlowDetailsRec);
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
    public static List<FieldsWrapper> fetchFieldsOfSelectedObject( String sObjectApiName, String instanceUrl)
    {
        OAuthFlowDetails__c oAuthFlowDetailsRec = checkAndReturnCurrentUserOauthRec_Internal('WebServerFlowWithPKCE');
        String accessToken = CalloutHelper.doDecryption(oAuthFlowDetailsRec.Access_Token__c);

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
    public static List<Object> fetchRecords(String sObjectApiName, String commaSeparatedFieldsList, String instanceUrl, String soqlQueryClauseVal)
    {
        OAuthFlowDetails__c oAuthFlowDetailsRec = checkAndReturnCurrentUserOauthRec_Internal('WebServerFlowWithPKCE');
        String accessToken = CalloutHelper.doDecryption(oAuthFlowDetailsRec.Access_Token__c);

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