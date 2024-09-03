public with sharing class QuickBooksConnectLwcController
{
    
    /**
     * This method return the auth code url
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getCompleteUrlForAuthCode()
    {
        qb_Metadata__mdt quickBooksConfig = qb_Metadata__mdt.getInstance('QuickBooksConfig');

        // return error if no custom metadata rec found
        if(quickBooksConfig == null)
        {
            return new Map<String, Object> {
                                                'isSuccess' => false,
                                                'errorMessage' => 'No QuickBooks Config found'
                                            };
        }

        

        try
        {
            String authUrl                  = (String)quickBooksConfig.get('auth_url__c');
            String clientId                 = (String)quickBooksConfig.get('Client_Id__c');
            String state                    = (String)quickBooksConfig.get('State__c');
            String redirectUri              = EncodingUtil.urlEncode(System.URL.getorgDomainURL().toExternalForm() + '/apex/' + (String)quickBooksConfig.get('PageName__c'), 'UTF-8');
            String scopes                   = EncodingUtil.urlEncode((String)quickBooksConfig.get('Scopes__c'), 'UTF-8'); 
        

            /**
             * V. Imp Weierd Observation while constructing the authUrl
             * If I Donot mainintain the same order of parameters as in the actual URL
             * The request fails with error code 400
             * I have to to copy the order from below working URL from Postman ie.e fisrt response_type then client_id then state then scope then redirect_uri
             * //https://appcenter.intuit.com/connect/oauth2?response_type=code&client_id=ABBquvxhUH0SDQaLhANviuOaUqpgDfUTemNFDYVppvPdMcxCsG&state=ae4fe533-6e70-40f1-a60e-ad052539fb08&scope=com.intuit.quickbooks.accounting%20com.intuit.quickbooks.payment%20openid%20profile%20email%20phone%20address&redirect_uri=https%3A%2F%2Foauth.pstmn.io%2Fv1%2Fcallback
             */
            String completeUrlForAuthCode   = authUrl + '?response_type=code&client_id=' + clientId + '&state='+state + '&scope='+scopes+'&redirect_uri='+redirectUri;
            System.System.debug('completeUrlForAuthCode = '+completeUrlForAuthCode);

            return new Map<String, Object> {
                                                'isSuccess' => true,
                                                'completeUrlForAuthCode' => completeUrlForAuthCode

                                            };
        }
        catch (Exception e)
        {
            throw new AuraHandledException(e.getMessage());
        }
    }



    /**
     * This method fetches the access token and other details once the code is obtained
     */
    @AuraEnabled
    public static Map<String, Object> getAccessRefreshToken(String code, String realmId, String state)
    {
        // throw error if either code or state is blank
        if(String.isBlank(code) || String.isBlank(realmId) || String.isBlank(state))
        {
            throw new AuraHandledException('Either code or state or realmId is blank');
        }

        qb_Metadata__mdt quickBooksConfig = qb_Metadata__mdt.getInstance('QuickBooksConfig');

        // return error if no custom metadata rec found
        if(quickBooksConfig == null)
        {
            throw new AuraHandledException('No QuickBooks Config found');
        }

        // throw exception if state doesnt; match
        if(!state.equalsIgnoreCase((String)quickBooksConfig.get('State__c')))
        {
            throw new AuraHandledException('State does not match');
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint(quickBooksConfig.token_url__c);
        req.setMethod('POST');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

        String redirectUri  = EncodingUtil.urlEncode(System.URL.getorgDomainURL().toExternalForm() + '/apex/' + (String)quickBooksConfig.get('PageName__c'), 'UTF-8');
        String reqBody      = 'grant_type=authorization_code&code=' + code +'&redirect_uri='+redirectUri+'&client_id='+quickBooksConfig.Client_Id__c+'&client_secret='+quickBooksConfig.Client_Secret__c;
        req.setBody(reqBody);
        System.debug('reqBody = '+reqBody);

        Http h              = new Http();
        HttpResponse res    = new HttpResponse();


        try 
        {
            res = h.send(req);

            if(res.getStatusCode() == 200 || res.getStatusCode() == 201)
            {
                System.debug('res.getBody() = '+res.getBody());
                Map<String, Object> mappedResponse = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());

                String access_token  = (String)mappedResponse.get('access_token');
                String refresh_token = (String)mappedResponse.get('refresh_token');
                //String realmId = (String)mappedResponse.get('access_token');
                //String accessToken = (String)mappedResponse.get('access_token');

                Map<String, Object> customFieldValuesMap = new Map<String, Object>();
                customFieldValuesMap.put('access_token__c', EncryptionDecryptionHelper.doEncryption(access_token));
                customFieldValuesMap.put('refresh_token__c', EncryptionDecryptionHelper.doEncryption(refresh_token));
                customFieldValuesMap.put('realmId__c', realmId);

                CreateUpdateMetadataUtils.createUpdateMetadata('qb_Metadata__mdt.QuickBooksConfig','QuickBooksConfig', customFieldValuesMap);

                return new Map<String, Object> {
                                                    'isSuccess' => true,
                                                    'response' => mappedResponse
                                                };
            }
            else
            {
                throw new MyException('Access token req failed. Details:'+res.getStatus()+' . Response Body='+res.getBody());    
            }
        } 
        catch (Exception e) 
        {
            throw new AuraHandledException(e.getMessage());
        }
    }



    /**
     * MEthod to get PRODUCTS from SF. 
     */
    @AuraEnabled
    public static List<Product2> getSFProducts()
    {        
        try
        {
            return [SELECT Id, Name, ProductCode, Description, IsActive, CreatedDate, Is_Synced_With_QuickBooks__c, QuickBooks_Id__c 
                        FROM Product2
                        WHERE IsActive = true
                        ORDER BY CreatedDate DESC];
        }
        catch (Exception e)
        {
            throw new AuraHandledException(e.getMessage());
        }
    }


    /**
     * Method to sync producs with QuickBooks
     */
    @AuraEnabled
    public static Map<String, Object> syncProductsInQuickBooks(List<Id> productsIdsToSync, Boolean useNamedCredentails)
    {
        System.debug('syncProductsInQuickBooks called with productsIdsToSync = '+productsIdsToSync);

        List<Product2> listOfProductsToSync = [SELECT Id, Name, ProductCode, Description, IsActive, CreatedDate, Is_Synced_With_QuickBooks__c, QuickBooks_Id__c 
                                                FROM Product2
                                                WHERE IsActive = true
                                                AND Id IN :productsIdsToSync
                                                AND Is_Synced_With_QuickBooks__c = false];

        // check if the list is empty
        if(listOfProductsToSync == null || listOfProductsToSync.size() == 0)
        {
            throw new AuraHandledException('All Porducts selected are already synced');
        }

        
        List<qb_Metadata__mdt> quickBooksConfigList = [SELECT Id, DeveloperName, MasterLabel, Language, NamespacePrefix, Label, QualifiedApiName, SystemModstamp, Environment__c, Client_Id__c, Client_Secret__c, Company_Info__c, Create_Bill__c, Create_Customer__c, Create_Estimate__c, Create_Invoice__c, Create_Payment__c, Create_Vendor__c, Customer_Url__c, PageName__c, Prod_Base_URL__c, Sanbdox_Base_URL__c, access_token__c, auth_url__c, expires_in__c, expires_in_time__c, minorversion__c, realmId__c, refresh_token__c, token_type__c, token_url__c, Create_Item__c, Scopes__c, State__c FROM qb_Metadata__mdt Where DeveloperName='QuickBooksConfig'];

        // return error if no custom metadata rec found
        if(quickBooksConfigList == null || quickBooksConfigList.size() == 0)
        {
            throw new AuraHandledException('No QuickBooks Config found');
        }

        qb_Metadata__mdt quickBooksConfig = quickBooksConfigList[0];

        List<Product2> productsWithQuickBooksIdToBeUpdated = new List<Product2>();
        
        // common for both named credentials as well as normal flow
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');

        System.debug('useNamedCredentails = '+useNamedCredentails);
        if(!useNamedCredentails)
        {
            String baseUrl = quickBooksConfig.Environment__c.equalsIgnoreCase('sandbox')? quickBooksConfig.Sanbdox_Base_URL__c : quickBooksConfig.Prod_Base_URL__c;
            String minorVersion = quickBooksConfig.minorversion__c;
            String realmId = quickBooksConfig.realmId__c;
            String createItemUrl = quickBooksConfig.Create_Item__c.replace('{{realmId}}', realmId).replace('{{minorVersion}}', minorVersion);
            String createItemCompleteEndpointUrl = baseUrl + createItemUrl;
            String decryptedAccessToken = EncryptionDecryptionHelper.doDecryption(quickBooksConfig.access_token__c);
            
            req.setEndpoint(createItemCompleteEndpointUrl);
            req.setHeader('Accept', 'application/json');
            req.setHeader('Authorization', 'Bearer '+decryptedAccessToken);
        }
        else // specific for named credential flow. here we have already set the Header('Accept', 'application/json') in CUstom Header section of external credential
        {
            System.debug('syncProductsInQuickBooks --> using Named Credentials: QuickBooksCommon');
            req.setEndpoint('callout:QuickBooksCommon/v3/company/9341453012483787/item?minorversion=73');
                
        }
        
        try
        {
            for(Product2 eachProduct : listOfProductsToSync)
            {
                Http h = new Http();
                HttpResponse res = new HttpResponse();
                
                String reqBody =		'{'+
                                    '  "TrackQtyOnHand": true, '+
                                    '  "Name": "' + eachProduct.Name +'", '+
                                    '  "QtyOnHand": 10, '+
                                    '  "IncomeAccountRef": {'+
                                    '    "name": "Sales of Product Income", '+
                                    '    "value": "79"'+
                                    '  }, '+
                                    '  "AssetAccountRef": {'+
                                    '    "name": "Inventory Asset", '+
                                    '    "value": "81"'+
                                    '  }, '+
                                    '  "InvStartDate": "2015-01-01", '+
                                    '  "Type": "Inventory", '+
                                    '  "ExpenseAccountRef": {'+
                                    '    "name": "Cost of Goods Sold", '+
                                    '    "value": "80"'+
                                    '  }'+
                                    '}';

                req.setBody(reqBody); 
                System.debug('reqBody is '+reqBody);                   
                res = h.send(req);
                System.debug('res.getStatusCode() = '+res.getStatusCode());

                if(res.getStatusCode() == 200 || res.getStatusCode() == 201)
                {
                    System.debug('success res.getBody() = '+res.getBody());

                    Map<String, Object> mappedResponse = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());

                    String quickBooksItemId = (String)((Map<String, Object>)mappedResponse.get('Item')).get('Id');
                    eachProduct.QuickBooks_Id__c = quickBooksItemId;
                    eachProduct.Is_Synced_With_QuickBooks__c = true;
                    productsWithQuickBooksIdToBeUpdated.add(eachProduct);
                }
                else
                {
                    throw new MyException('Status code is not 200. Status: '+res.getStatus()+' and body='+res.getBody());
                }

                
            }

            if(productsWithQuickBooksIdToBeUpdated.size() > 0)
            {
                update productsWithQuickBooksIdToBeUpdated;
                return new Map<String, Object>{
                        'isSuccess' => true,
                        'successMessage' => 'Success! ' + productsWithQuickBooksIdToBeUpdated.size() + ' products have been successfully synced with QuickBooks, and their respective QuickBooks IDs have been updated in the corresponding Salesforce records.'
                };
            }
            else{

                return new Map<String, Object>{
                        'isSuccess' => false,
                        'errorMessage' => 'No products were synced with QuickBooks and the corresponding QuickBooks Ids were updated in Salesforce product.'
                };
            }
        }
        catch (Exception e) 
        {
            throw new AuraHandledException(e.getMessage());
        }
    }


    // custom exception class
    class MyException extends Exception {}
}