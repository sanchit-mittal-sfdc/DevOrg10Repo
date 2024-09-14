public inherited sharing class GmailntegrationRedirectVFController {
    public String redirectUrl { get; set; }

    public GmailntegrationRedirectVFController() {
        String code = ApexPages.currentPage().getParameters().get('code');
        String state = ApexPages.currentPage().getParameters().get('state');
        
        // Construct the URL for your LWC
        //redirectUrl = 'https://wonton-deploy-6437-dev-ed.scratch.lightning.force.com/lightning/n/OAuth_2_0_Web_Server_Flow_WITH_PKCE';
        redirectUrl = System.URL.getOrgDomainUrl().toExternalForm() + '/lightning/n/Gmail_Integration';

        if (code != null) {
            redirectUrl += '?c__code=' + code;
        }
        if (state != null) {
            redirectUrl += '&c__state=' + state;
        }
    }
}