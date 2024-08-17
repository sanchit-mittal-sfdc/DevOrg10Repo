public with sharing class FetchAuthCodeAndAccessTokenVFCls
{
    Private String authCode; 
    Sfdc_Config__mdt config;
    public String sfdcconfigname { get; set; }


    public FetchAuthCodeAndAccessTokenVFCls()
    {
        

        // This URL parameter will get passed from the LWC component SalesforceToSalesforceIntegrationLwc using NavigationMixin.navigate method containing the details of which ORG the user has selected to re-authorize.
        Map<String, String> params = ApexPages.currentPage().getParameters();
        
        if(params?.containsKey('sfdcconfigname'))
        {
            System.debug('LWC passed the URL parameter sfdcconfigname to the VF page. Value='+Sfdc_Config__mdt.getInstance( params.get('sfdcconfigname') ));
            config = Sfdc_Config__mdt.getInstance( params.get('sfdcconfigname') );
        }
    }

    /*
    iMP: Earlier I was using the below code in constructor but then the metadata was not getting dpeloyed due to unknown reasons.
    */
    public PageReference getAccessToken()
    {
        System.debug('getAccessToken called');
        Map<String, String> params = ApexPages.currentPage().getParameters();
        
        if(params != null && params.containsKey('code'))
        {
            authCode = params.get('code');
            system.debug('parameter code=' + authCode);
            
            //Sfdc_Config__mdt config = Sfdc_Config__mdt.getInstance(System.Label.SFDC_Config_Record_To_Use);
            Sfdc_Config__mdt config = Sfdc_Config__mdt.getInstance(sfdcconfigname);
            
            System.debug('config = '+config);
            if( config != null)
            {                
                // We can use this as well if you want that you should be able to integrate any random org. This is covered in user Agent Flow. hence commenting it from here.
                //String baseUrl = config.Environment__c.equalsIgnoreCase('Production') ? 'https://login.salesforce.com' : 'https://test.salesforce.com';
                //System.debug('Env = '+config.Environment__c +'. Hence, baseUrl = '+baseUrl);
                
                String baseUrl = 'https://' + config.Domain_URL_of_Org_To_be_Integrated__c;
                System.debug('baseUrl = '+baseUrl);
                
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
                System.debug('body = '+body);
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
                        System.debug('Org: '+ config.Label + ' is successfully authorized. You may now close this tab and switch back to the original tab/window');
                        
                        Map<String, Object> mapRes = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                        
                        ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.CONFIRM, 'Org: '+ config.Label + ' is successfully authorized. You may now close this tab and switch back to the original tab/window');
                        ApexPages.addMessage(myMsg);
                        

                        Map<String, Object> fieldWithValuesMap = new Map<String, Object>();
                        fieldWithValuesMap.put('AccessToken__c', (String)mapRes.get('access_token'));
                        fieldWithValuesMap.put('Refresh_Token__c', (String)mapRes.get('refresh_token'));
                        fieldWithValuesMap.put('Instance_URL__c', (String)mapRes.get('instance_url'));

                        //DateTime dt = System.now();
                        //String issuedAtVal = dt.format('dd-MMM-yyyy') +' at '+ dt.format('h:mm a');
                        //fieldWithValuesMap.put('Issued_at__c', issuedAtVal);
                        fieldWithValuesMap.put('Issued_at__c', System.now());
                        
                        String fullName = 'SFDC_Config__mdt.'+config.DeveloperName;
                        String metadataLabel = config.Label;
                        CreateUpdateMetadataUtils.createUpdateMetadata(fullName, metadataLabel, fieldWithValuesMap); //  here "__mdt" is oprtional, even "SFDC_Config" will work
                    
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
        return null;
    }
    
    public PageReference getAuthCode()
    {
        System.debug('getAuthCode called');
        Sfdc_Config__mdt config;

        // This URL parameter will get passed from the LWC component SalesforceToSalesforceIntegrationLwc using NavigationMixin.navigate method containing the details of which ORG the user has selected to re-authorize.
        Map<String, String> params = ApexPages.currentPage().getParameters();
        
        if(params?.containsKey('sfdcconfigname'))
        {
            System.debug('LWC passed the URL parameter sfdcconfigname to the VF page. Value='+Sfdc_Config__mdt.getInstance( params.get('sfdcconfigname') ));
            config = Sfdc_Config__mdt.getInstance( params.get('sfdcconfigname') );
        }

        
        
        if( config != null)
        {
            
            String finalAuthCodeUrl; //'https://test.salesforce.com/services/oauth2/authorize?client_id=3MVG9vuHjyLKuxlGk4tw9N.0dEiTR0uQlyAEEEcVWdcj0euGbcJrMIyubaoAPP31py6Vgs8ULSLfIyQj5L6_A&redirect_uri=https://agility-page-4023-dev-ed--c.scratch.vf.force.com/apex/FetchAuthCodeAndAccessTokenVF&response_type=code';
            
            // We can use this as well if you want that you should be able to integrate any random org. This is covered in user Agent Flow. hence commenting it from here.
            //String baseUrl = config.Environment__c.equalsIgnoreCase('Production') ? 'https://login.salesforce.com' : 'https://test.salesforce.com';

            String baseUrl = 'https://' + config.Domain_URL_of_Org_To_be_Integrated__c;
            System.debug('baseUrl = '+baseUrl);
            //System.debug('Env = '+config.Environment__c +'. Hence, baseUrl = '+baseUrl);
            
            String authCodeUrl = config.Auth_Code_URL__c;
            System.debug('authCodeUrl = '+authCodeUrl);
            
            String clientId = config.ClientID__c;
            String pageName = config.Page_Name__c;
            
            String orgDOmainUrl = URL.getOrgDomainURL().toExternalForm();

            String redirectUri = orgDOmainUrl + '/apex/' + pageName;
            redirectUri = EncodingUtil.urlEncode(redirectUri, 'UTF-8');
            
            finalAuthCodeUrl = baseUrl + authCodeUrl + '?client_id=' + clientId + '&redirect_uri=' + redirectUri + '&response_type=code';
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