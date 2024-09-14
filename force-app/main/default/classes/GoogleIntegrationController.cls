public inherited sharing class GoogleIntegrationController 
{
    // This method is exposed to the client (LWC) and is cacheable for better performance.
    @AuraEnabled(cacheable=true)
    public static Map<String,Object> getAuthUrl()
    {
        // Fetch the Google configuration from custom metadata 'Google__mdt' using the unique developer name 'Google_Config'.
        List<Google__mdt> googleConfigList = [SELECT Id, DeveloperName, Client_ID__c, Client_Secret__c, Auth_URL__c, Token_URL__c, Scopes__c 
                                                FROM Google__mdt
                                                WHERE DeveloperName = 'Google_Config'];

        // If no configuration is found, throw an exception with a custom message.
        if(googleConfigList == null || googleConfigList.size() == 0)
        {
            throw new AuraHandledException('No Google_Config found.');
        }

        Google__mdt googleConfig = googleConfigList.get(0);
        /**
         * Sample authorization URL structure:
         * https://accounts.google.com/o/oauth2/v2/auth?
         *   scope=https%3A//www.googleapis.com/auth/drive.metadata.readonly&
         *   access_type=offline&
         *   include_granted_scopes=true&
         *   response_type=code&
         *   state=state_parameter_passthrough_value&
         *   redirect_uri=https%3A//oauth2.example.com/code&
         *   client_id=client_id
         * 
         * We'll dynamically construct this URL below using the config values.
         */

        try
        {
            // Base authorization URL from Google configuration (stored in custom metadata).
            String authUrl              = googleConfig.Auth_URL__c;

            // URL-encoded scope parameter (Google API scopes), encoding done to make it safe for URLs.
            String scope                = EncodingUtil.urlEncode(googleConfig.Scopes__c, 'UTF-8');

            // Access type defines whether the refresh token is returned. 'offline' grants the ability to refresh tokens.
            String accessType           = 'offline';

            // If true, granted scopes are included in the response.
            String includeGrantedScopes = 'true';

            // Response type indicates what the authorization server will return. 'code' is used for OAuth 2.0 authorization code flow.
            String responseType         = 'code';

            // State parameter is a custom value to maintain state between the request and callback. It could be anything, here it's 'sanchit'.
            String state                = 'sanchit';

            /**
             * IMP: If you donot set it t consent then you wont receive the refresh_token after 1 st 
             *  succesfull call. lets say you tested it in postman and you received the refresh token alognh 
             *  with access token. But then whn you use salesforce to get the access token you will only receive 
             *  the access token. hence setting it to 'consent' amkes sure every time the user gives the consent 
             *  and every time you receive the refresh token as well
             */
            String prompt               = 'consent';

            // Get the client id
            String clientId = googleConfig.Client_Id__c;

            // Redirect URI is the endpoint where Google will send the authorization code after the user grants access.
            // We're constructing the URL to a Visualforce page in our Salesforce org  which will further rediredt the LWC
            String redirectUri          = EncodingUtil.urlEncode(System.URL.getOrgDomainUrl().toExternalForm() + '/apex/GmailIntegrationRedirectHelperVF', 'UTF-8');

            // Construct the final authorization URL by appending all the necessary query parameters.
            String finalAuthUrl = authUrl 
                                + '?scope=' + scope 
                                + '&access_type=' + accessType 
                                + '&include_granted_scopes=' + includeGrantedScopes 
                                + '&response_type=' + responseType 
                                + '&state=' + state 
                                + '&redirect_uri=' + redirectUri
                                + '&client_id=' + clientId
                                + '&prompt='+ prompt;

            System.System.debug('finalAuthUrl = '+finalAuthUrl);
            // Return a map containing success status and the constructed authorization URL.
            return new Map<String, Object>{
                                            'isSuccess' => true,
                                            'authUrl' => finalAuthUrl
                                        };
        
        } catch (Exception e) {
            // Catch any exceptions that occur during the process and throw an AuraHandledException with the error message.
            throw new AuraHandledException(e.getMessage());
        }
    }




    // Method to get an access token from Google's OAuth 2.0 service using an authorization code
    public static Map<String, Object> getAccessToken(String authCode)
    {
        // Fetch the Google configuration from custom metadata 'Google__mdt' using the unique developer name 'Google_Config'.
        Google__mdt googleConfig = Google__mdt.getInstance('Google_Config');

        // If no configuration is found, return a map with an error message indicating that the configuration is missing.
        if (googleConfig == null)
        {
            return new Map<String, Object> {
                'isSuccess' => false,
                'errorMessage' => 'No Google_Config found.'
            };
        }

        /**
         * Example of the token request format:
         * POST /token HTTP/1.1
         * Host: oauth2.googleapis.com
         * Content-Type: application/x-www-form-urlencoded
         *
         * code=authorization_code&
         * client_id=your_client_id&
         * client_secret=your_client_secret&
         * redirect_uri=https%3A//oauth2.example.com/code&
         * grant_type=authorization_code
         */

        // Token URL from the Google configuration in custom metadata.
        String tokenUrl = googleConfig.Token_URL__c;

        // Authorization code passed into the method (obtained from the Google OAuth flow).
        String code = authCode;

        // Client ID and secret from the Google configuration (these identify your app).
        String client_id = googleConfig.Client_Id__c;
        String client_secret = googleConfig.Client_Secret__c;

        // The redirect URI must match what was used in the authorization request.
        String redirectUri = EncodingUtil.urlEncode(System.URL.getOrgDomainUrl().toExternalForm() + '/apex/GmailIntegrationRedirectHelperVF', 'UTF-8');

        // The grant type must be 'authorization_code' for exchanging the code for tokens.
        String grant_type = 'authorization_code';

        // Construct the request body for the token exchange. Parameters are URL-encoded.
        String reqBody = 'code=' + code + '&' +
                        'client_id=' + client_id + '&' +
                        'client_secret=' + client_secret + '&' +
                        'redirect_uri=' + redirectUri + '&' +
                        'grant_type=' + grant_type;

        // Create a new HTTP request object to send the POST request.
        HttpRequest req = new HttpRequest();
        req.setEndpoint(tokenUrl);  // Set the token URL endpoint.
        req.setMethod('POST');  // HTTP POST method.
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');  // Set the required content type.
        req.setBody(reqBody);  // Set the request body with the encoded parameters.

        try 
        {
            // Initialize HTTP client to send the request.
            Http h = new Http();
            
            // Send the request and get the response.
            HttpResponse res = h.send(req);

            // Log the response body for debugging purposes.
            System.debug('res.getBody()' + res.getBody());

            // If the response status is 200 (OK) or 201 (Created), process the response.
            if (res.getStatusCode() == 200 || res.getStatusCode() == 201)
            {
                // Deserialize the JSON response into a map.
                Map<String, Object> mappedResponse = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());

                // Return a success response with the relevant token data.
                return new Map<String, Object> {
                    'isSuccess' => true,
                    'access_token' => (String)mappedResponse.get('access_token'),  // Access token for API calls.
                    'refresh_token' => (String)mappedResponse.get('refresh_token'),  // Refresh token for getting new access tokens.
                    'expires_in' => (Integer)mappedResponse.get('expires_in'),  // Expiry time of the access token.
                    'token_type' => (String)mappedResponse.get('token_type')  // Token type (usually 'Bearer').
                };
            }
            else if (res.getStatusCode() >= 400 && res.getStatusCode() < 500) {
                return new Map<String, Object> {
                    'isSuccess' => false,
                    'errorMessage' => 'Client error occurred: ' + res.getBody()
                };
            } 
            else if (res.getStatusCode() >= 500) {
                return new Map<String, Object> {
                    'isSuccess' => false,
                    'errorMessage' => 'Server error occurred: ' + res.getBody()
                };
            }
            else 
            {
                // If the response status is not successful, return an error message with the response details.
                return new Map<String, Object> {
                    'isSuccess' => false,
                    'errorMessage' => 'Something went wrong while fetching access token. Details: ' + res.getBody()
                };
            }
        } 
        catch (Exception e) 
        {
            // Catch any exceptions and return an error message with details.
            return new Map<String, Object> {
                'isSuccess' => false,
                'errorMessage' => 'Some error occurred while fetching access token. Error Message: ' + e.getMessage()
            };
        }
    }



    // This method exchanges the authorization code received from Google for an access token and stores the token details in Salesforce.
    // It is exposed to Lightning components via @AuraEnabled.
    @AuraEnabled
    public static Map<String, Object> exchangeTokenForAccessToken(String authCode, String stateReceived)
    {
        System.debug('exchangeTokenForAccessToken called with authCode= '+authCode +' and stateReceived= '+stateReceived);
        // Check if the authCode or stateReceived is null or blank.
        if (String.isBlank(authCode) || String.isBlank(stateReceived))
        {
            // Throw a custom AuraHandledException if either parameter is missing.
            throw new AuraHandledException('authCode or stateReceived is null');
        }

        // Validate the state parameter to ensure it matches the expected value 'sanchit'.
        if (!stateReceived.equals('sanchit'))
        {
            // If the state doesn't match, throw an error to prevent CSRF attacks.
            throw new AuraHandledException('State parameter not matching!');
        }

        try
        {
            // Call the method to get the access token using the provided authorization code.
            Map<String, Object> tokenDetails = getAccessToken(authCode);

            // Check if the token retrieval was successful by inspecting the 'isSuccess' flag.
            if (tokenDetails.get('isSuccess') == true)
            {
                Boolean isCurrentUserExistingGmailDetails = false;
                List<OAuthFlowDetails__c> currentUserExistingGmailDetails= [SELECT Id, Name, User__c, Access_Token__c, Refresh_Token__c, Application__c, Expires_at_Time__c 
                                                                            FROM OAuthFlowDetails__c
                                                                            WHERE User__c = :System.UserInfo.getUserId() AND Application__c = 'GmailIntegrationApp'];
                
                // If the token details are successfully retrieved, check if an OAuth record exists in Salesforce.
                OAuthFlowDetails__c googleAuthDetailsForCurrentUser;
                if(currentUserExistingGmailDetails == null || currentUserExistingGmailDetails.size() == 0)
                {
                    googleAuthDetailsForCurrentUser = new OAuthFlowDetails__c();

                    // Set the User__c field to the current user's ID (user initiating the OAuth flow).
                    googleAuthDetailsForCurrentUser.User__c = System.UserInfo.getUserId();

                    googleAuthDetailsForCurrentUser.Application__c = 'GmailIntegrationApp';
                }
                else
                {
                    isCurrentUserExistingGmailDetails = true;
                    googleAuthDetailsForCurrentUser = currentUserExistingGmailDetails[0];
                }
        
                
                
                // Store the access token received from Google in Encrypted format
                googleAuthDetailsForCurrentUser.Access_Token__c =  EncryptionDecryptionHelper.doEncryption((String)tokenDetails.get('access_token'));

                // Store the refresh token for future use, although the current implementation doesn't use it to refresh the access token.
                googleAuthDetailsForCurrentUser.Refresh_Token__c = EncryptionDecryptionHelper.doEncryption((String)tokenDetails.get('refresh_token'));
                
                // Calculate the expiration time for the access token and store it in Salesforce.
                googleAuthDetailsForCurrentUser.Expires_at_Time__c = System.now().addSeconds((Integer)tokenDetails.get('expires_in'));
                
                
                if(isCurrentUserExistingGmailDetails)
                {
                    // Insert the OAuth details into Salesforce.
                    update googleAuthDetailsForCurrentUser;
                }
                else
                {
                    insert googleAuthDetailsForCurrentUser;
                }
                

                // Return a success response indicating the token exchange was successful.
                return new Map<String, Object> {
                    'isSuccess' => true
                };
            }
            else
            {
                // If the token exchange failed, throw a custom GoogleCustomException with the error message.
                throw new GoogleCustomException((String)tokenDetails.get('errorMessage'));
            }
        }
        catch (Exception e)
        {
            // Catch any exceptions and throw a custom AuraHandledException with the error message.
            throw new AuraHandledException(e.getMessage());
        }
    }


    // toVal, ccVal, bccVal can have multiple email addresses separated by semi colon like sanchit.4010@gmail.com;sanchit2010@gmail.com
    @AuraEnabled
    public static Map<String, object> sendEmailViaGmail(Boolean shouldUseNamedCredentials, String toVal, String ccVal, String bccVal, String subjectVal, String bodyVal)
    {
        System.debug('sendEmailViaGmail called');
        System.debug('toVal = '+toVal);
        System.debug('ccVal = '+ccVal);
        System.debug('bccVal = '+bccVal);
        System.debug('subjectVal = '+subjectVal);
        System.debug('bodyVal = '+bodyVal);

        if(shouldUseNamedCredentials == null)
        {
            return new Map<String, Object>{
                    'isSuccess' => false,
                    'errorMessage' => 'shouldUseNamedCredentials is null'
            };
        }

        if(String.isBlank(toVal) || String.isBlank(subjectVal) || String.isBlank(bodyVal))
        {
            return new Map<String, Object>{
                    'isSuccess' => false,
                    'errorMessage' => 'To, Subject and Body cannot be blank'
            };
            
        }
        // fetch the access token from custom object if shouldUseNamedCredentials = false;
        OAuthFlowDetails__c googleAuthDetailsForCurrentUser;

        if(!shouldUseNamedCredentials)
        {
            List<OAuthFlowDetails__c> currentUserExistingGmailDetails= [SELECT Id, Name, User__c, Access_Token__c, Refresh_Token__c, Application__c, Expires_at_Time__c 
                                                                            FROM OAuthFlowDetails__c
                                                                            WHERE User__c = :System.UserInfo.getUserId() AND Application__c = 'GmailIntegrationApp'];
                
            googleAuthDetailsForCurrentUser = currentUserExistingGmailDetails[0];
        }

        // Fetch the Google configuration from custom metadata 'Google__mdt' using the unique developer name 'Google_Config'.
        List<Google__mdt> googleConfigList = [SELECT Id, DeveloperName, Client_ID__c, Client_Secret__c, Auth_URL__c, Token_URL__c, Scopes__c 
                                                FROM Google__mdt
                                                WHERE DeveloperName = 'Google_Config'];

        // If no configuration is found, throw an exception with a custom message.
        if(googleConfigList == null || googleConfigList.size() == 0)
        {
            return new Map<String, Object> {
                'isSuccess' => false,
                'errorMessage' => 'No Google_Config found.'
            };
        }

        Google__mdt googleConfig = googleConfigList.get(0);

        // Create a new HTTP request object to send the POST request.
        HttpRequest req = new HttpRequest();
        

        System.debug('shouldUseNamedCredentials is '+shouldUseNamedCredentials);
        if(shouldUseNamedCredentials)
        {
            //  named credentials has enpoint url till /messages i.e https://gmail.googleapis.com/gmail/v1/users/me/messages so we need to append /send
            req.setEndpoint('callout:GmailPerUser/send');

            System.debug('using named credentials GmailPerUser');
        }
        else
        {
            req.setEndpoint('https://gmail.googleapis.com/gmail/v1/users/me/messages/send');
            req.setHeader('Content-Type', 'Application/json');
            req.setHeader('Authorization', 'Bearer ' + EncryptionDecryptionHelper.doDecryption(googleAuthDetailsForCurrentUser.Access_Token__c));
        }

        req.setMethod('POST');  // HTTP POST method.


        


        try 
        {
            /**
             * V. Imp Part is to create the value that has to be passed to "raw" attribute which contains all the ino in Base 64 encoded format. 
             */
            String reqBody = createRawEmail(toVal, ccVal, bccVal, subjectVal, bodyVal);
            req.setBody(reqBody);  // Set the request body with the encoded parameters.


            // Initialize HTTP client to send the request.
            Http h = new Http();
            
            // Send the request and get the response.
            HttpResponse res = h.send(req);

            // Log the response body for debugging purposes.
            System.debug('res.getBody()' + res.getBody());

            // If the response status is 200 (OK) or 201 (Created), process the response.
            if (res.getStatusCode() == 200 || res.getStatusCode() == 201)
            {
                // Deserialize the JSON response into a map.
                Map<String, Object> mappedResponse = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());

                // Return a success response with the relevant token data.
                return new Map<String, Object> {
                                                    'isSuccess' => true,
                                                    'id' => (String)mappedResponse.get('id'),  
                                                    'threadId' => (String)mappedResponse.get('threadId')
                                                };
            }
            else if (res.getStatusCode() >= 400 && res.getStatusCode() < 500) 
            {
                return new Map<String, Object> {
                                                    'isSuccess' => false,
                                                    'errorMessage' => 'Client error occurred: ' + res.getBody()
                                                };
            } 
            else if (res.getStatusCode() >= 500) 
            {
                return new Map<String, Object> {
                                                    'isSuccess' => false,
                                                    'errorMessage' => 'Server error occurred: ' + res.getBody()
                                                };
            }
            else 
            {
                // If the response status is not successful, return an error message with the response details.
                return new Map<String, Object> {
                    'isSuccess' => false,
                    'errorMessage' => 'Something went wrong while fetching access token. Details: ' + res.getBody()
                };
            }

        } 
        catch (Exception e) 
        {
            return new Map<String, Object> {
                                        'isSuccess' => false,
                                        'errorMessage' => 'Some error occurred while fetching access token. Error Message: ' + e.getMessage()
                                    };
        }
    }


    /**
     *  To: sanchit.251291@gmail.com,sanchit.4010.phonebackup@gmail.com
        Cc: sanchit.salesforce@gmail.com
        Bcc: sanchit.4010.drive1@gmail.com
        Subject: Test Gmail API with multiple To, Cc and Bcc fields

        This is the body of the email.
        Please click the below link for zoom:

        https://us05web.zoom.us/s/82844645445?zak=eyJ0eXAiOiJKV1QiLCJzdiI6IjAwMDAwMSIsInptX3NrbSI6InptX28ybSIsImFsZyI6IkhTMjU2In0.eyJpc3MiOiJ3ZWIiLCJjbHQiOjAsIm1udW0iOiI4Mjg0NDY0NTQ0NSIsImF1ZCI6ImNsaWVudHNtIiwidWlkIjoiSTRXWFJPYXVTNDJLMVQ5aVJNRGItQSIsInppZCI6IjI5MzRlZTA3YjIzNjRjZWRiYTc2YzFiYjU0N2RkMWRkIiwic2siOiIwIiwic3R5IjoxMDAsIndjZCI6InVzMDUiLCJleHAiOjE3MjYxMjc5NjgsImlhdCI6MTcyNjEyMDc2OCwiYWlkIjoiRDRremFKLWFTM0dYZXNVQkdjb2FaUSIsImNpZCI6IiJ9.HTjR8caAnsyFBJEShZVo3hmBaLlXdr1LepGXtpZvtDY

        #SFDCAMigo

        Thanks,
        Sanchit

     */
    // Method to create a raw email message in MIME format
    public static String createRawEmail(String toVal, String ccVal, String bccVal, String subjectVal, String bodyVal) 
    {
        // Ensure required fields are not blank
        if (String.isBlank(toVal) || String.isBlank(subjectVal) || String.isBlank(bodyVal)) {
            throw new IllegalArgumentException('To, Subject, and Body cannot be blank');
        }
        
        // Initialize the list to hold email lines
        List<String> emailLines = new List<String>();
        
        // Add headers to the emailLines list
        emailLines.add('To: ' + toVal.replace(';', ', ')); // Replace ';' with commas for valid formatting

        if (String.isNotBlank(ccVal)) 
        {
            emailLines.add('Cc: ' + ccVal.replace(';', ', ')); // Replace ';' with commas for valid formatting
        }

        if (String.isNotBlank(bccVal)) 
        {
            emailLines.add('Bcc: ' + bccVal.replace(';', ', ')); // Replace ';' with commas for valid formatting
        }

        emailLines.add('Subject: ' + subjectVal);
        emailLines.add('Content-Type: text/html; charset=UTF-8'); // Assuming HTML content
        emailLines.add('MIME-Version: 1.0');
        emailLines.add(''); // Empty line to separate headers from body
        
        // Add the body of the email
        emailLines.add(bodyVal);

        // Combine the lines into a single string with CRLF line endings
        String rawMessage = String.join(emailLines, '\r\n');
        
        // Encode the MIME message in Base64
        Blob rawMessageBlob = Blob.valueOf(rawMessage);
        String base64EncodedMessage = EncodingUtil.base64Encode(rawMessageBlob);
        
        System.debug('raw attribute created ='+base64EncodedMessage);
        // Return the JSON body for the Gmail API
        return '{"raw": "' + base64EncodedMessage + '"}';
    }
    



    // custom Exception class
    public class GoogleCustomException extends Exception {}
}