public with sharing class EncryptionDecryptionHelper
{
    
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


    /* Execute this method in Developer Console to generate the key
    String encryptionKey = EncryptionKeyGenerator.generateEncryptionKey();
    System.debug('Generated Encryption Key: ' + encryptionKey);
    */
    public static String generateEncryptionKey() 
    {
        // Generate a 32-byte random key
        Blob key = Crypto.generateAesKey(256); // 256-bit key for AES-256
        // Encode the key in Base64 for storage
        String encodedKey = EncodingUtil.base64Encode(key);
        return encodedKey;
    }
}