public inherited sharing class LinkedinIntegrationLwcController 
{
    // Returns the details required for auth code flow to LWC
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getDetailsForAuthCodeFlow()
    {
        try
        {
            SFDC_Config__mdt linkedinConfigRec = SFDC_Config__mdt.getInstance('Linkedin_Config');


            if(linkedinConfigRec == null)
            {
                throw new AuraHandledException('No config record found for SFDC_Config__mdt.Linkedin_Config');
            }
            else
            {
                String redirectUri = System.URL.getOrgDomainUrl().toExternalForm() + '/apex/LinkedinIntegrationRedirectHelperVF';
                redirectUri = EncodingUtil.urlEncode(redirectUri, 'UTF-8');
                return new Map<String, Object>{
                                                'ClientID__c'       => linkedinConfigRec.ClientID__c,
                                                'Redirect_URL__c'   => redirectUri,
                                                'State__c'          => linkedinConfigRec.State__c,
                                                'Scope__c'          => linkedinConfigRec.Scope__c
                                            };

            }
        }
        catch (Exception e)
        {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // return the linkedIn congif record 
    public static SFDC_Config__mdt getLinkedInConfigRec()
    {
        try {
            return SFDC_Config__mdt.getInstance('Linkedin_Config');
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }


    /**
     * This is called from LWC on page load only if the code and state paramters are present i.e. when th LWC is being loaded as a result of redirect. 
     * This function will further call getLinkedinAccessToken to update the access token in custom object OAuthFlowDetails__c
     * */ 

    @AuraEnabled
    public static Map<String, object> updateLinkedinUserIdAccessTokenInOAuthFlowDetails(String code, String stateInRedirect)
    {
        // if Either code or stateInRedirect is blank, then simply exit with an error message
        if(String.isBlank(code) || String.isBlank(stateInRedirect))
        {
            throw new AuraHandledException('Either code or stateInRedirect is blank!');
        }
        
        SFDC_Config__mdt linkedinConfigRec = LinkedinIntegrationLwcController.getLinkedInConfigRec();

        // Step 1: Validate if the state is matching or not. if not, throw an error back to the app
        if(!stateInRedirect.equals(linkedinConfigRec.State__c))
        {
            throw new AuraHandledException('State is not matching');
        }

        // Step 2: GET Access TOKEN and LinkedIn User ID USING 2 separate callouts and update the custom object

        Map<String, object> accessTokenFetchResult = LinkedinIntegrationLwcController.fetchLinkedinUserIdAccessTokenAndUpdateOathFlowRec(code);
        
        // if there was any error then return the same message back to LWC
        if(!(Boolean)accessTokenFetchResult.get('isSuccess'))
        {
            throw new AuraHandledException((String)accessTokenFetchResult.get('errorMessage'));
        }
        else // if all good, return the map with isSuccess=true
        {
            return accessTokenFetchResult;
        }
    }




    /**
     * TO GET THE ACCESS TOKEN as well as the LINKEDIN USER ID which is required for publishing posts or other callouts
     * IMP: I always use Map<String, object> as return type so that I can return more info as key value pair without altering any code.
     */
    private static Map<String, object> fetchLinkedinUserIdAccessTokenAndUpdateOathFlowRec(String code)
    {
        // return if code is balnk
        if(String.isBlank(code))
        {
            return new Map<String, Object>{
                                            'isSuccess'    => false,
                                            'errorMessage' => 'Code is blank'
                                        };
        }

        SFDC_Config__mdt linkedinConfigRec = LinkedinIntegrationLwcController.getLinkedInConfigRec();

        // Make callout if code is not blank
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint('https://www.linkedin.com/oauth/v2/accessToken');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

        // This redirect_uri has to be same as the one which was passed to get the auth code
        String redirectUri = System.URL.getOrgDomainUrl().toExternalForm() + '/apex/LinkedinIntegrationRedirectHelperVF';
        redirectUri = EncodingUtil.urlEncode(redirectUri, 'UTF-8');
        //String redirectUri = 'https%3A%2F%2Fwonton-deploy-6437-dev-ed.scratch.lightning.force.com%2Fapex%2FLinkedinIntegrationRedirectHelperVF';

        String reqBody = 'grant_type=authorization_code&code='+code+'&client_id='+linkedinConfigRec.ClientID__c+'&client_secret='+linkedinConfigRec.ClientSecret__c+'&redirect_uri='+redirectUri;
        req.setBody(reqBody);
        System.debug('reqBody = '+reqBody);

        Http h              = new Http();
        HttpResponse res    = new HttpResponse();

        try
        {
            res = h.send(req);

            if(res.getStatusCode() == 200 || res.getStatusCode() == 201)
            {
                System.debug('Access TOken Request: res.getStatusCode() is either 200 or 201');

                // Now get the Access Token if everthing is fine
                Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                String accessToken              = (String)responseMap.get('access_token');
                //String LinkedinUserId           = (String)responseMap.get(); 
                if(String.isNotBlank(accessToken))
                {
                    // NOW WE HAVE TO FETCH THE LINKEDIN USER ID FOR USING ONE MORE CALLOUT
                    req = new HttpRequest();
                    req.setMethod('GET');
                    req.setEndpoint('https://api.linkedin.com/v2/userinfo');
                    req.setHeader('Accept', 'application/json');
                    req.setHeader('Authorization', 'Bearer '+accessToken);

                    h   = new Http();
                    res = new HttpResponse();


                    res = h.send(req);

                    if(res.getStatusCode() == 200 || res.getStatusCode() == 201)
                    {
                        System.debug('Linkedin User ID Request: res.getStatusCode() is either 200 or 201');
                        responseMap                     = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                        String linkedinUserId           = (String)responseMap.get('sub'); 

                        
                        // First Delete if by any chance there is any existing record for this user
                        LinkedinIntegrationLwcController.deleteOuthFlowDetailsRec();

                        // Now insert the new record with encrypted access token and UserId
                        // Insert the Custom Object OAuthFlowDetails with the encrytped access token and User Id and will be deleteing this record when user logs out or closes the tab/window.
                        OAuthFlowDetails__c oauthDetails    = new OAuthFlowDetails__c();
                        oauthDetails.Application__c         = 'LinkedinIntegration';
                        oauthDetails.User__c                = UserInfo.getUserId();
                        oauthDetails.LinkedIn_User_Id__c    = linkedinUserId;
                        oauthDetails.Access_Token__c        = CalloutHelper.doEncryption(accessToken);
                        insert oauthDetails;

                        return new Map<String, Object>{
                                                            'isSuccess'    => true,
                                                            'errorMessage' => null,
                                                            'userName'     => (String)responseMap.get('given_name'),
                                                            'userPicture'  => (String)responseMap.get('picture')
                                                    };

                    }
                    else
                    {
                        System.debug('Linkedin User ID Request: : res.getStatusCode() is neither 200 nor 201');
                        return new Map<String, Object>{
                                                        'isSuccess'    => false,
                                                        'errorMessage' => 'Linkedin User ID Request: res.getStatusCode() is neither 200 nor 201. Error:'+res.getStatus()
                                                     };
                    }
                }
                else
                {
                    return new Map<String, Object>{
                                                    'isSuccess'    => false,
                                                    'errorMessage' => 'access_token is found blank in successfull callout.'
                                            };
                }

                
            }
            else
            {
                System.debug('Access TOken Request: res.getStatusCode() is neither 200 nor 201');
                return new Map<String, Object>{
                                                'isSuccess'    => false,
                                                'errorMessage' => 'Access TOken Request: res.getStatusCode() is neither 200 nor 201. Error:'+res.getStatus()
                                        };
            }
        }
        catch(Exception e)
        {
            System.System.debug('Some error occured while making callout to fetch the access token. Details:' + e.getMessage());
            return new Map<String, Object>{
                                            'isSuccess'    => false,
                                            'errorMessage' => 'Some error occured while making callout to fetch the access token. Details:' + e.getMessage()
                                        };
        }
    }




    
    /**
     * This method is called from LWC when user explicitly logs out or when closes the tab or window
     * It will basically delete those OAuthFlowDetails records where user id = current user id and 
     */
    @AuraEnabled
    public static Map<string, Object> deleteOuthFlowDetailsRec()
    {
        System.debug('deleteOuthFlowDetailsRec called');
        try 
        {
            delete [SELECT Id FROM OAuthFlowDetails__c WHERE User__c = :UserInfo.getUserId() AND Application__c = 'LinkedinIntegration' ];
            return new Map<String, Object>{
                                            'isSuccess'    => true,
                                            'errorMessage' => null
                                        };
        } 
        catch (Exception e)
        {
            throw new AuraHandledException(e.getMessage());
        }
    }


    @AuraEnabled
    public static Map<String, Object> sharePostOnLinkedIn(String body)
    {
        System.debug('sharePostOnLinkedIn called with body='+body);

        // check if the body is blank
        if(String.isBlank(body))
        {
            throw new AuraHandledException('Body cannot be blank');
        }

        // SOQL to fetch the current user ouathdetails record
        List<OAuthFlowDetails__c> currentUserLinkedInOauthDetailsList = new List<OAuthFlowDetails__c>();
        currentUserLinkedInOauthDetailsList                           = [SELECT Id , Access_Token__c, LinkedIn_User_Id__c 
                                                                                    FROM OAuthFlowDetails__c 
                                                                                    WHERE User__c = : UserInfo.getUserId() 
                                                                                    AND Application__c = 'LinkedinIntegration'
                                                                                    ORDER BY CreatedDate DESC];

        // Throw an error if no or more than 1 rec found                                                                                   
        if(currentUserLinkedInOauthDetailsList.size() != 1)
        {
            throw new AuraHandledException('Size of currentUserLinkedInOauthDetailsList is not 1 i.e. Either no or more than 1 record found for current user');
		}

        OAuthFlowDetails__c currentUserLinkedInOauthDetailsRec = currentUserLinkedInOauthDetailsList[0];
		
        // else check if the access token and linkedin user are not blank . If yes then again throw an error bacl to LWC
        if(String.isBlank(currentUserLinkedInOauthDetailsRec.Access_Token__c) || String.isBlank(currentUserLinkedInOauthDetailsRec.LinkedIn_User_Id__c))
		{

            throw new AuraHandledException('Access TOken or LinkedIn UserId is blank. Please logout and re-login again');
		
        }


        // If all good then set the variables
        String accessToken         = CalloutHelper.doDecryption(currentUserLinkedInOauthDetailsRec.Access_Token__c);
        String linkedinUserId       = currentUserLinkedInOauthDetailsRec.LinkedIn_User_Id__c;

        // make a callout to publish the post
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint('https://api.linkedin.com/v2/ugcPosts');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer '+accessToken);
        req.setHeader('X-Restli-Protocol-Version', '2.0.0');
        

        String reqBody = '{'+
		'    "author": "urn:li:person:' + linkedinUserId + '",'+
		'    "lifecycleState": "PUBLISHED",'+
		'    "specificContent": {'+
		'        "com.linkedin.ugc.ShareContent": {'+
		'            "shareCommentary": {'+
		'                "text": "' + body + '"'+
		'            },'+
		'            "shareMediaCategory": "NONE"'+
		'        }'+
		'    },'+
		'    "visibility": {'+
		'        "com.linkedin.ugc.MemberNetworkVisibility": "CONNECTIONS"'+
		'    }'+
		'}';        

        req.setBody(reqBody);

        System.debug('reqBody = '+reqBody);

        Http h = new Http();
        HttpResponse res = new HttpResponse();

          
        try
        {
            res = h.send(req);

            System.debug('res.getStatusCode() = '+res.getStatusCode());
            System.debug('res.getStatus() = '+res.getStatus());
            System.debug('res.getBody() = '+res.getBody());
            if(res.getStatusCode() == 200 || res.getStatusCode() == 201)
            {
                return new Map<String, Object>{
                                                'isSuccess'    => true,
                                                'statusCode'   => res.getStatusCode(),
                                                'response'     => res.getBody()
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
            throw new AuraHandledException('Some error occurred while publising the post. Error details: '+e.getMessage());
        }
    }


    // custom execption class
    //public class LinkedinIntegrationException extends Exception {}
}