public with sharing class ZoomIntegrationController 
{
    /**
     * This method creates a meeting
     * 
     * ZoomIntegrationController.createZoomMeeting();
     * Testing:
     * ZoomIntegrationController.createZoomMeetingAndSendInvite(false, 'Test Topic', 2, '2024-10-25T07:45:55Z', 60, '', 'test agenda', new list<String>{'sanchit.salesforce@gmail.com', 'sanchit.9july2024@gmail.com'}, '');
     */
    @AuraEnabled
    public static Map<String, Object> createZoomMeetingAndSendInvite(Boolean isFutureMeeting, String topic, Integer meetingType, String start_time, Integer duration, String timezone, String agenda, List<String> attendeesEmailList, String hostEmail)
    {
        System.debug('createZoomMeetingAndSendInvite called with attendeesEmailList='+attendeesEmailList);
        // check if attendeesEmailList is null or empty
        if(attendeesEmailList == null || attendeesEmailList.size() <= 0)
        {
            throw new AuraHandledException('Please provide at least one attendee email address');
        }

        if(meetingType == null)
        {
            throw new AuraHandledException('Meeting Type is null');
        }

        if(String.isBlank(timezone))
        {
            timezone = UserInfo.getTimeZone().toString();
        }

        // If hostEMail is blank then it means the current user is the host and should be receiving the start_url
        if(String.isBlank(hostEmail))
        {
            hostEmail = UserInfo.getUserEmail();
        }




        try
        {
            Map<String, object> createMeetingResponseMap = fetchZoomMeetingUrl(isFutureMeeting, topic, meetingType, start_time, duration, timezone, agenda);

            if ((Boolean)createMeetingResponseMap.get('isSuccess') == true)
            {
                // Prepare email for attendees
                Messaging.SingleEmailmessage emailToAttendees = new Messaging.SingleEmailmessage();
                emailToAttendees.setToAddresses(attendeesEmailList);
                emailToAttendees.setSubject('Zoom Meeting Invite');

                // Dynamic email body based on whether it's a future meeting or an instant meeting
                String attendeesEmailBody = 'Hello,\n\n';
                attendeesEmailBody += 'You are invited to join a ';
                if (isFutureMeeting)
                {
                    attendeesEmailBody += 'scheduled meeting. Please find the details below:\n\n';
                    attendeesEmailBody += 'Meeting Start Time: ' + start_time + '\n';
                }
                else
                {
                    attendeesEmailBody += 'meeting happening now. Please find the details below:\n\n';
                }
                attendeesEmailBody += 'Join the meeting via the following link:\n';
                attendeesEmailBody += createMeetingResponseMap.get('join_url') + '\n\n';
                attendeesEmailBody += 'Looking forward to your participation.\n\n';
                attendeesEmailBody += 'Best regards,\n';
                attendeesEmailBody += 'Your Name';
                emailToAttendees.setPlainTextBody(attendeesEmailBody);

                // Prepare email to the host with the zoom start_url
                Messaging.SingleEmailmessage emailToHost = new Messaging.SingleEmailmessage();
                emailToHost.setToAddresses(new List<String>{hostEmail});
                emailToHost.setSubject('Zoom Meeting Details for Host');

                // Dynamic email body for the host based on meeting type
                String hostEmailBody = 'Hi ' + UserInfo.getFirstName() + ',\n\n';
                if (isFutureMeeting)
                {
                    hostEmailBody += 'You are the host of this scheduled meeting. Please click the link below to start the meeting at ' + start_time + ':\n\n';
                }
                else
                {
                    hostEmailBody += 'You are the host of this instant meeting. Please click the link below to start the meeting:\n\n';
                }
                hostEmailBody += createMeetingResponseMap.get('start_url') + '\n';
                emailToHost.setPlainTextBody(hostEmailBody);

                // Send the emails to attendees and host
                List<Messaging.SendEmailResult> sendEmailResults = Messaging.sendEmail(new List<Messaging.SingleEmailmessage>{emailToAttendees, emailToHost});

                // Handle email send result
                for (Messaging.SendEmailResult eachResult : sendEmailResults)
                {
                    if (!eachResult.isSuccess())
                    {
                        System.debug('Error occurred in sending email: ' + eachResult.getErrors()[0].getMessage());
                        throw new CustomZoomException(eachResult.getErrors()[0].getMessage());
                    }
                }

                // Return success result
                return new Map<String, Object> {
                    'isSuccess' => true,
                    'hostEmail' => hostEmail,
                    'join_url' => createMeetingResponseMap.get('join_url'),
                    'start_url' => createMeetingResponseMap.get('start_url')
                };

            }
            else
            {
                throw new CustomZoomException((String)createMeetingResponseMap.get('errorMessage'));
            }
        }
        catch (Exception e)
        {
            throw new AuraHandledException(e.getMessage());
        }

    }


    /**
     * NOTE:
     * This method is used to get the zoom meeting url using Named Credentials: ZoomCommon 
     * 
     * ################## Execute the below code in Dev console to get the zoom meeting url ###################
     * ZoomIntegrationController.fetchZoomMeetingUrl();
     * 
     * ################## Execute the below code in Dev console to get the access token ###################
     * ZoomIntegrationController.fetchZoomMeetingUrl();
     *  {
            "topic": "My Meeting2",
            "type": 2,
            "start_time": "2022-03-25T07:45:55Z",
            "duration": 60,
            "timezone": "Asia/Calcutta",
            "agenda": "My Meeting Agenda"
        }

     */
    public static Map<String, object> fetchZoomMeetingUrl(Boolean isFutureMeeting, String topic, Integer meetingType, String start_time, Integer duration, String timezone, String agenda)
    {
        // preparing request body
        Map<String, Object> reqBodyMap = new Map<String, Object>();
        
        if(String.isNotBlank(topic))
        {
            reqBodyMap.put('topic', topic);
        }
        if(meetingType != null)
        {
            reqBodyMap.put('type', meetingType);
        }
        if(duration != null)
        {
            reqBodyMap.put('duration', duration);
        }
        if(String.isNotBlank(timezone))
        {
            reqBodyMap.put('timezone', timezone);
        }
        if(String.isNotBlank(agenda))
        {
            reqBodyMap.put('agenda', agenda);
        }
        if(isFutureMeeting && String.isNotBlank(start_time))
        {
            reqBodyMap.put('start_time', start_time);
        }

        String reqBody = JSON.serialize(reqBodyMap);
        System.debug('reqBody = '+reqBody);

    

        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint('callout:ZoomCommon/users/me/meetings');
        req.setHeader('Content-Type','application/json');
        req.setBody(reqBody);


        Http h = new Http();

        try
        {
            HttpResponse res = h.send(req);

            if(res.getStatusCode() == 200 || res.getStatusCode() == 201)
            {
                System.System.debug('zoom success create meeting response = '+ JSON.serializePretty( (Map<String, Object>)JSON.deserializeUntyped(res.getBody())) );                
                Map<String, Object> authResponseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                System.debug('start_url='+((String) authResponseMap.get('start_url')));
                return new Map<String, Object>{
                                                'isSuccess' => true,
                                                'start_url' => (String) authResponseMap.get('start_url'),
                                                'join_url' => (String) authResponseMap.get('join_url')
                                            };
            }
            else
            {
                System.System.debug('Zoom API call returned non-success code = '+res.getStatusCode()+' and status='+res.getStatus()+' and response body='+res.getBody());
                return new Map<String, object> {
                                                'isSuccess' => false,
                                                'errorMessage' => 'Zoom API call for create meeting returned non-success code = '+res.getStatusCode()+' and status='+res.getStatus()+' and response body='+res.getBody()
                                            };
            }
    
        }
        catch (Exception e)
        {
            return new Map<String, object> {
                                            'isSuccess' => false,
                                            'errorMessage' => 'Error occurred while making callout to create meeting. Error Message='+e.getMessage()
                                     };
        }
        
    }




    
    /**
     * NOTE: NO LONGER NEEDED SINCE NAMED CREDENTIALS ARE BEING USED
     * 
     * This method is used to get the access token from Zoom API using Account Credentials flow(similar to client credentials flow 
     * for server to server integration which does not require any user interaction and does not return any refresh token). 
     * the access token is short-lived just for 1 hr and we can simple request the new access token if it expires using the same method.
     * 
     * ################## Execute the below code in Dev console to get the access token ###################
     * ZoomIntegrationController.getZoomAccessToken();
     *
    public static Map<String, object> getZoomAccessToken()
    {
        Zoom__mdt zoomConfig = Zoom__mdt.getInstance('Zoom_Config');

        if(zoomConfig == null)
        {
            return new Map<String, object>{
                                             'isSuccess' => false,
                                             'errorMessage' => 'Zoom__mdt.getInstance(\'Zoom Config\') returned null'
                                         };
        }

        String clientId         = zoomConfig.Client_ID__c;
        String clientSecret     = zoomConfig.Client_Secret__c;
        String accountId        = zoomConfig.Account_ID__c;
        String tokenUrl         = zoomConfig.Token_URL__c;
        String reqBody          = 'grant_type=client_credentials&account_id='+accountId; 

        //Encode the client ID and client secret in base64 format (with a colon between them, e.g. client_id:client_secret).
        String encodedClientIdAndSecret = EncodingUtil.base64Encode( Blob.valueOf(clientId + ':' + clientSecret) );

        


        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint(tokenUrl);
        req.setHeader('Content-Type','application/x-www-form-urlencoded');
        req.setHeader('Authorization', 'Basic '+encodedClientIdAndSecret);
        req.setBody(reqBody);


        Http h = new Http();

        try
        {
            HttpResponse res = h.send(req);

            if(res.getStatusCode() == 200 || res.getStatusCode() == 201)
            {
                System.System.debug('zoom success token response = '+ JSON.serializePretty( (Map<String, Object>)JSON.deserializeUntyped(res.getBody())) );                
                Map<String, Object> authResponseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                System.debug('access token='+((String) authResponseMap.get('access_token')));
                return new Map<String, Object>{
                                                'isSuccess' => true,
                                                'access_token' => (String) authResponseMap.get('access_token'),
                                                'expires_in' => (Integer) authResponseMap.get('expires_in'),
                                                'token_type' => (String) authResponseMap.get('token_type')
                                            };
            }
            else
            {
                System.System.debug('Zoom API call returned non-success code = '+res.getStatusCode()+' and status='+res.getStatus()+' and response body='+res.getBody());
                return new Map<String, object> {
                                                'isSuccess' => false,
                                                'errorMessage' => 'Zoom API call returned non-success code = '+res.getStatusCode()+' and status='+res.getStatus()+' and response body='+res.getBody()
                                            };
            }
    
        }
        catch (Exception e)
        {
            return new Map<String, object> {
                                            'isSuccess' => false,
                                            'errorMessage' => 'Error occurred while making callout to get access token. Error Message='+e.getMessage()
                                     };
        }
        
    }
    */


    /**
     * This method creates a meeting
     * 
     * ZoomIntegrationController.createZoomMeeting();
     *
    @AuraEnabled
    public static void createZoomMeeting()
    {
        List<Zoom__mdt> zoomConfigList = [SELECT Id, DeveloperName, Access_Token__c, Auth_URL__c, Token_URL__c, Client_ID__c, Client_Secret__c, Base_URL__c, Account_ID__c, Expires_at__c 
                                            FROM Zoom__mdt
                                            WHERE DeveloperName = 'Zoom_Config'
                                            LIMIT 1];
        
        

        if(zoomConfigList == null || zoomConfigList.size() != 1)
        {
            throw new AuraHandledException('Invalid Zoom Configuraation');
        }

        Zoom__mdt zoomConfig                            = zoomConfigList[0];
        Map<String, Object> valuesToUpdateInZoomConfig  = new Map<String, Object>();

        

        try
        {
            // check if the access token is present in metadata. If yes, then check whther its still valid or not
            if( String.isBlank(zoomConfig.Access_Token__c) || zoomConfig.Expires_at__c < System.now())
            {
                // get the new access token
                Map<String, object> accessTokenResponse = getZoomAccessToken();
                System.debug('accessTokenResponse='+accessTokenResponse);

                if((Boolean)accessTokenResponse.get('isSuccess') == true)
                {
                    valuesToUpdateInZoomConfig.put('Access_Token__c',(String) accessTokenResponse.get('access_token'));

                    Integer expires_in = (Integer)accessTokenResponse.get('expires_in');
                    
                    // calculate the expiration time of the access token
                    valuesToUpdateInZoomConfig.put('Expires_at__c',System.now().addSeconds(expires_in));

                    Map<String, object> createMeetingResponseMap = fetchZoomMeetingUrl((String) accessTokenResponse.get('access_token'), 'test meeting', 1);
                    
                    CreateUpdateMetadataUtils.createUpdateMetadata('Zoom__mdt.Zoom_Config','Zoom Config', valuesToUpdateInZoomConfig);
                }
            }
            else
            {
                // get the existing access token
                String accessToken = zoomConfig.Access_Token__c;

                Map<String, object> createMeetingResponseMap = fetchZoomMeetingUrl(accessToken, 'test meeting', 1);
            }
        }
        catch (Exception e)
        {
            throw new AuraHandledException(e.getMessage());
        }
    }
    */
    
    // Custom Exception class
    public class CustomZoomException extends Exception {}
    
}