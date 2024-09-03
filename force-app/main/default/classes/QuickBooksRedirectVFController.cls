public inherited sharing class QuickBooksRedirectVFController {
    public String redirectUrl { get; set; }

    public QuickBooksRedirectVFController() {
        String code = ApexPages.currentPage().getParameters().get('code');
        String state = ApexPages.currentPage().getParameters().get('state');
        String realmId = ApexPages.currentPage().getParameters().get('realmId');
        
        // Construct the URL for your LWC
        //redirectUrl = 'https://wonton-deploy-6437-dev-ed.scratch.lightning.force.com/lightning/n/OAuth_2_0_Web_Server_Flow_WITH_PKCE';
        redirectUrl = System.URL.getOrgDomainUrl().toExternalForm() + '/lightning/n/QuickBooks_Connect';

        if (String.isNotBlank(code)) {
            redirectUrl += '?c__code=' + code;
        }
        if (String.isNotBlank(state)) {
            redirectUrl += '&c__state=' + state;
        }
        if (String.isNotBlank(realmId)) {
            redirectUrl += '&c__realmId=' + realmId;
        }
        
    }
}