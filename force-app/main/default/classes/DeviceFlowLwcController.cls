public with sharing class DeviceFlowLwcController
{
    @AuraEnabled
    public static Map<String, Object> getDeviceCodeAndVerificationLink()
    {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://login.salesforce.com/services/oauth2/token');
        req.setMethod('POST');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

        String reqBody = 'response_type=device_code&client_id=3MVG9ZL0ppGP5UrAYqpIcm8xwPZkZCgAz_ci2OHdQmR5q1xgBdhmyEkR3iL7TNKWXBQWz1RKYUdISZDMuiYX0&scope=api';
        req.setBody(reqBody);

        Http h           = new Http();
        HttpResponse res = new HttpResponse();

        try
        {
            res = h.send(req);
            System.debug('response body='+res.getBody());

            if(res.getStatusCode()  == 200 || res.getStatusCode()  == 201)
            {
                Map<String, Object> mappedResponse = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                return new Map<String, Object> {
                                                        'isSuccess' => true,
                                                        'device_code' => (String)mappedResponse.get('device_code'),
                                                        'user_code' => (String)mappedResponse.get('user_code'),
                                                        'verification_uri' => (String)mappedResponse.get('verification_uri'),
                                                        'interval' => (Integer)mappedResponse.get('interval')
                                                };
            }
            else
            {
                System.debug('Status code is '+res.getStatusCode());
                return new Map<String, Object> {
                                                        'isSuccess' => false,
                                                        'errorMessage' => 'Error occurred while fetching device code. Error: '+res.getStatus()
                                                };
            }
        }
        catch (Exception e)
        {
            throw new AuraHandledException(e.getMessage());
        }
    }




    @AuraEnabled
    public static Map<String, Object> checkDeviceAuthenticationStatus(String device_code)
    {
        if(String.isBlank(device_code))
        {
            return new Map<String, Object> {
                                                'isSuccess' => false,
                                                'errorMessage' => 'Invalid device code'
                                        };
        }
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://login.salesforce.com/services/oauth2/token');
        req.setMethod('POST');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

        String reqBody = 'grant_type=device&client_id=3MVG9ZL0ppGP5UrAYqpIcm8xwPZkZCgAz_ci2OHdQmR5q1xgBdhmyEkR3iL7TNKWXBQWz1RKYUdISZDMuiYX0&code='+device_code;
        req.setBody(reqBody);

        Http h           = new Http();
        HttpResponse res = new HttpResponse();

        try
        {
            res = h.send(req);
            System.debug('response body='+res.getBody());

            if(res.getStatusCode()  == 200 || res.getStatusCode()  == 201)
            {
                Map<String, Object> mappedResponse = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                return new Map<String, Object> {
                                                        'isSuccess' => true,
                                                        'access_token' => (String)mappedResponse.get('access_token')
                                                };
            }
            else
            {
                System.debug('Status code is '+res.getStatusCode());
                return new Map<String, Object> {
                                                        'isSuccess' => false,
                                                        'errorMessage' => 'Error occurred while fetching device code. Error: '+res.getStatus()
                                                };
            }
        }
        catch (Exception e)
        {
            throw new AuraHandledException(e.getMessage());
        }
    }
}