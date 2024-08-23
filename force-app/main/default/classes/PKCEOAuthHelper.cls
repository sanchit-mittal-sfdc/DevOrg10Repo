public class PKCEOAuthHelper {
    
    public static void printDetails(){
        
        String code_verifier  = SFDC_GENERATE_RANDOM_STRING(56);
        Blob sha256 		  = Crypto.generateDigest('SHA-256', Blob.valueOf(code_verifier));
        String code_challenge = SFDC_BASE64_URLENCODE(sha256);
        
        System.debug('**** code_verifier **** \n  '+code_verifier);
        System.debug('**** code_challenge **** \n '+code_challenge);
    }
    
    private static String SFDC_BASE64_URLENCODE(final Blob input){
        if(input == null) {
            return null;
        }
        return EncodingUtil.base64Encode(input)
            .replace('/', '_')
            .replace('+', '-')
            .replaceAll('=+$', '');
    }
    
    private static String SFDC_BASE64_URL_ENCODE(Blob input){
        String output = encodingUtil.base64Encode(input);
        output = output.replace('+', '-');
        output = output.replace('/', '_');
        while ( output.endsWith('=')){
            output = output.subString(0,output.length()-1);
        }
        return output;
    }
    
    private static String SFDC_GENERATE_RANDOM_STRING(Integer len) {
        final String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz';
        String randStr = '';
        while (randStr.length() < len) {
            Integer idx = Math.mod(Math.abs(Crypto.getRandomInteger()), chars.length());
            randStr += chars.substring(idx, idx+1);
        }
        return randStr; 
    }
    
}