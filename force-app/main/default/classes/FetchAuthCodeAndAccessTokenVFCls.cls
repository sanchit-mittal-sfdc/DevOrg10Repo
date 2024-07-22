public with sharing class FetchAuthCodeAndAccessTokenVFCls
{
    Private String authCode;
    
    public FetchAuthCodeAndAccessTokenVFCls()
    {
        System.debug('constructor called');
        Map<String, String> params = ApexPages.currentPage().getParameters();
        
        if(params != null && params.containsKey('code'))
        {
            authCode = params.get('code');
            system.debug('parameter code=' + authCode);
            
            Sfdc_Config__mdt config = Sfdc_Config__mdt.getInstance('Salesforce_Dev10_SO');
            
            if( config != null)
            {                
                String baseUrl = config.Environment__c.equalsIgnoreCase('Production/Dev') ? 'https://login.salesforce.com' : 'https://test.salesforce.com';
                System.debug('Env = '+config.Environment__c +'. Hence, baseUrl = '+baseUrl);
                
                String accessTokenUrl = config.Access_Token_URL__c;
                System.debug('accessTokenUrl = '+accessTokenUrl);
                
                String clientId = config.ClientID__c;
                String clientSecret = config.ClientSecret__c;
                String pageName = config.Page_Name__c;
                
                String orgDOmainUrl = URL.getOrgDomainURL().toExternalForm();
                
                
                HttpRequest req = new HttpRequest();
                req.setMethod('POST');
                req.setEndpoint(baseUrl + accessTokenUrl);
                req.setHeader('Content-Type','application/x-www-form-urlencoded');
                req.setHeader('Accept','application/json');
                
                //grant_type=authorization_code&
                //code=aPrxhgZ2MIpkSy0aOdn07LjKFvsFOis6RGcWXz7p8JQCjcqfed5NQLe7sxWwMY_JQFuLwHRaRA==&
                //client_id=3MVG9IHf89I1t8hrvswazsWedXWY0iqK20PSFaInvUgLFB6vrcb9bbWFTSIHpO8G2jxBLJA6uZGyPFC5Aejq&
                //client_secret=*******************&
                //redirect_uri=https://www.mycustomerorderstatus.com/oauth2/callback
                
                String body = 'grant_type=authorization_code&code=' + authCode + '&client_id=' + clientId + '&client_secret=' + clientSecret + '&redirect_uri=' + orgDOmainUrl + '/apex/'+ pageName;
                req.setBody(body);
                
                Http h = new Http();
                
                Httpresponse res;
                
                try
                {
                    res = h.send(req);
                }
                catch(CalloutException e)
                {
                    System.debug('FAiled callout to get access token. CalloutException:'+e.getMessage());
                    ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR, e.getMessage());
                    ApexPages.addMessage(myMsg);
                }
                catch(Exception e)
                {
                    System.debug('FAiled callout to get access token. Exception:'+e.getMessage());
                    ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR, e.getMessage());
                    ApexPages.addMessage(myMsg);
                }
                
                if(res != null)
                {
                    System.debug('res.getStatusCode = '+res.getStatusCode());
                    System.debug('res.getBody = '+res.getBody());
                    
                    if(res.getStatusCode() == 200 || res.getStatusCode() == 201)
                    {
                        System.debug('Successfull callout to get access token');
                        
                        Map<String, Object> mapRes = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                        
                        ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.CONFIRM, 'Successfully fetched the Access Token');
                        ApexPages.addMessage(myMsg);
                        
                        
                        Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
                        
                        customMetadata.fullName = 'Sfdc_Config.Salesforce_Dev10_SO1'; 
                        // API Name - Custom metadata Record
                        
                        customMetadata.label = 'Salesforce Dev10 SO'; // 'Salesforce Token'
                        
                        Map<String, Object> fieldWithValuesMap = new Map<String, Object>();
                        fieldWithValuesMap.put('AccessToken__c', (String)mapRes.get('access_token'));
                        
                        for(String key : fieldWithValuesMap.keySet())
                        {
                            Metadata.CustomMetadataValue customField = new Metadata.CustomMetadataValue();
                            customField.field = key;
                            customField.value = fieldWithValuesMap.get(key);

                            customMetadata.values.add(customField);
                        }
                        Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
                        mdContainer.addMetadata(customMetadata);
                      
                        Id jobId = Metadata.Operations.enqueueDeployment(mdContainer, new CreateUpdateMetadataUtils());
                        
                    }
                    else
                    {
                        System.debug('Failed callout to get access token');
                        ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR, res.getBody());
                        ApexPages.addMessage(myMsg);
                    }
                }
                
            }
            else
            {
                ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR, 'No custom metadata config record found.');
                ApexPages.addMessage(myMsg);
            }
            
            
        }
        else
        {
            system.debug('parameter code is NOT present');
        }
        
    }
    
    public PageReference getAccessToken()
    {
        System.debug('getAccessToken called');
        Sfdc_Config__mdt config = Sfdc_Config__mdt.getInstance('Salesforce_Dev10_SO');
        
        if( config != null)
        {
            String finalAuthCodeUrl; //'https://test.salesforce.com/services/oauth2/authorize?client_id=3MVG9vuHjyLKuxlGk4tw9N.0dEiTR0uQlyAEEEcVWdcj0euGbcJrMIyubaoAPP31py6Vgs8ULSLfIyQj5L6_A&redirect_uri=https://agility-page-4023-dev-ed--c.scratch.vf.force.com/apex/FetchAuthCodeAndAccessTokenVF&response_type=code';
            
            String baseUrl = config.Environment__c.equalsIgnoreCase('Production/Dev') ? 'https://login.salesforce.com' : 'https://test.salesforce.com';
            System.debug('Env = '+config.Environment__c +'. Hence, baseUrl = '+baseUrl);
            
            String authCodeUrl = config.Auth_Code_URL__c;
            System.debug('authCodeUrl = '+authCodeUrl);
            
            String clientId = config.ClientID__c;
            String pageName = config.Page_Name__c;
            
            String orgDOmainUrl = URL.getOrgDomainURL().toExternalForm();
            
            finalAuthCodeUrl = baseUrl + authCodeUrl + '?client_id=' + clientId + '&redirect_uri=' + orgDOmainUrl + '/apex/'+ pageName + '&response_type=code';
            System.debug('finalAuthCodeUrl = '+finalAuthCodeUrl);
            
            return new PageReference(finalAuthCodeUrl);
        }
        else
        {
            ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR, 'No custom metadata config record found.');
            ApexPages.addMessage(myMsg);
            return null;
        }
        
    } 
    
    
        
}