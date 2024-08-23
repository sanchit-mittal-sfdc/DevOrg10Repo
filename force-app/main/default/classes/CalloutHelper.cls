public inherited sharing class CalloutHelper
{
    // To get the access token using regresh tokem
    public static String getSFAccessTokenUsingRefreshToken(String refreshToken, String instanceUrl, String clientId, String clientSecret)
    {
        if(String.isBlank(refreshToken) || String.isBlank(instanceUrl) || String.isBlank(clientId) || String.isBlank(clientSecret))
        {
            return null;
        }

        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint(instanceUrl+'/services/oauth2/token');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        
        String bodyString = 'grant_type=refresh_token&client_id='+clientId+'&client_secret='+clientSecret+'&refresh_token='+refreshToken;
        req.setBody(bodyString);

        Http h = new Http();
        HttpResponse res = new HttpResponse();
        
        try
        {
            res = h.send(req);

            if(res.getStatusCode() != 200)
            {
                 throw new CalloutHelperException('Failed to get access token using the refresh token. Please click the Log Out/Re-Authorize button and then login again. Status: '+res.getStatus());
            }

            Map<String, Object> mappedResponse = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());

            return (String)mappedResponse.get('access_token');
        }
        catch(Exception e)
        {
            throw new CalloutHelperException('CalloutHelper.getSFAccessTokenUsingRefreshToekn: Failed to get access token. ' + e.getMessage());
        }
    }


    // To encrypt the value
@AuraEnabled
public static String doEncryption(String plainTextVal) 
{
    Blob data = Blob.valueOf(plainTextVal);
    Blob key = getEncryptionKeyBlob(); // Correctly retrieve the key as a Blob
    Blob encryptedData = Crypto.encryptWithManagedIV('AES256', key, data);
    return EncodingUtil.base64Encode(encryptedData);
}

// To decrypt the value
@AuraEnabled
public static String doDecryption(String encryptedVal)
{
    Blob encryptedData = EncodingUtil.base64Decode(encryptedVal);
    Blob key = getEncryptionKeyBlob(); // Correctly retrieve the key as a Blob
    Blob decryptedData = Crypto.decryptWithManagedIV('AES256', key, encryptedData);
    return decryptedData.toString();
}

// To get the key as a Blob
@AuraEnabled
public static Blob getEncryptionKeyBlob()
{
    // Retrieve the base64 encoded key from custom metadata
    EncryptionKeyMetadata__mdt keyMetadata = [SELECT EncryptionKey__c FROM EncryptionKeyMetadata__mdt LIMIT 1];
    
    // Decode the base64 encoded key into a Blob
    Blob keyBlob = EncodingUtil.base64Decode(keyMetadata.EncryptionKey__c);
    
    // Ensure the key is exactly 32 bytes (256 bits) long for AES-256
    System.assert(keyBlob.size() == 32, 'Key must be 32 bytes (256 bits) long.');
    
    return keyBlob;
}



    // Custom Exception class
    public class CalloutHelperException extends Exception {}
}