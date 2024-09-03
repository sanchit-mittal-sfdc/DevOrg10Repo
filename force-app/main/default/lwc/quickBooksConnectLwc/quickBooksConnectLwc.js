import { LightningElement, wire, track } from 'lwc';
import getCompleteUrlForAuthCode from '@salesforce/apex/QuickBooksConnectLwcController.getCompleteUrlForAuthCode';
import getAccessRefreshToken from '@salesforce/apex/QuickBooksConnectLwcController.getAccessRefreshToken';
import getSFProducts from '@salesforce/apex/QuickBooksConnectLwcController.getSFProducts';
import syncProductsInQuickBooks from '@salesforce/apex/QuickBooksConnectLwcController.syncProductsInQuickBooks';
import Toast from 'lightning/toast';

const COLUMNS = [
    {
        label:"Sno",
        fieldName:"Sno",
        type:"number",
        cellAttributes: {
            alignment: "center" // Center align the Sno column
        },
        initialWidth: 100 // Set a minimal width for the Sno column
    },
    {
        label:"Product Name",
        fieldName:"Name",
        type:"text"
    },
    {
        label:"Product Code",
        fieldName:"ProductCode",
        type:"text"
    },
    {
        label:"Is Synced With QuickBooks?",
        fieldName:"Is_Synced_With_QuickBooks__c",
        type:"boolean"
    },
    {
        label:"QuickBooks ID (External Id)",
        fieldName:"QuickBooks_Id__c",
        type:"text"
    }

];

const PAGE_SIZE_OPTIONS = [
    {
        value: '5',
        label: '5'
    },
    {
        value: '10',
        label: '10'
    },
    {
        value: '15',
        label: '15'
    },
    {
        label:'20',
        value:'20'
    }

];

export default class QuickBooksConnectLwc extends LightningElement {

    urlForAuthCode;
    isUserLoggedIn = false; // FOR TESTING SETTING IT TRUE 
    isLoaded = true;
    wiredProductsResult; // this is used for refreshApex() since the wired result needs to be passed here.
    allProductsFromSf = []; // this contains all the products rerturn by sf apex i.e.e getSFProducts
    columns = COLUMNS;
    totalRecords;
    defaultPageSize = '10';
    totalPages;
    currentPageNumber = 1;
    pageSizeOptions = PAGE_SIZE_OPTIONS;
    @track paginatedRecords = [];
    currentPageNumberDetails;
    selectedRowsInTable = [];
    useNamedCredentials;

    // called in page load. Checks if code, c__realmId and state are present 
    async connectedCallback(){
        debugger;
        //https://wonton-deploy-6437-dev-ed.scratch.lightning.force.com/lightning/n/QuickBooks_Connect?c__code=AB11725262778Yc3uwxaEsP7Vq1j4xlBGpkOY8YgLTs9X7SQW3&c__state=state&c__realmId=9341453012483787
        const urlParamsString   = window.location.search;
        const urlParams         = new URLSearchParams(urlParamsString);
        const code              = urlParams.get('c__code');
        const state             = urlParams.get('c__state');
        const realmId           = urlParams.get('c__realmId');

        window.history.replaceState(null, null, window.location.href.split('?')[0]);

        /**
         * 
         *   VVVVVV IMPP
         * 
         * REMOVE THIS CODE FROM  HERE AFTER DEV
         * 
         * 
         **
        *
        try
        {
            const response = await getSFProducts({});
            debugger;
            if(response)
            {
                this.allProductsFromSf = response;
                this.recalculatePagination();
            }
        }
        catch(error)
        {
            console.error(error,body.message);
            this.allProductsFromSf = [];
            this.isLoaded = true;
        }*/


        if(code && state && realmId)
        {
            //alert(`code = ${code} state=${state} realmId=${realmId}`);
            try
            {
                this.isLoaded = false;
                const response = await getAccessRefreshToken({code, realmId, state});
                

                if(response.isSuccess)
                {
                    this.isUserLoggedIn = true;

                    this.fetchProductsFromSF('connectedCallback');

                    Toast.show({
                        label: 'Success',
                        message: 'Access Token and Refresh Token are saved successfully in encrypted format',
                        variant: 'success',
                        mode: 'dismissable'
                    }, this);
                }
            }
            catch(error)
            {
                this.isLoaded = true;
                Toast.show({
                    label: 'Error',
                    message: error.body.message,
                    variant: 'error',
                    mode: 'dismissable'
                }, this);
            }
        }

    }


    async fetchProductsFromSF(calledFrom){

        debugger;
        console.log(`fetchProductsFromSF called from ${calledFrom}`);
        this.isLoaded = true;
        const productsResponse = await getSFProducts({});
        debugger;
        this.isLoaded = true;
        debugger;
        if(productsResponse)
        {
            this.allProductsFromSf = productsResponse;
            this.recalculatePagination();
        }
        if(calledFrom == 'handleRefreshClick')
        {
            Toast.show({
                label: 'Success',
                 message: 'Products are refreshed successfully',
                 variant: 'success',
                 mode: 'dismissable'
            }, this);
        }
    }


    // To get the complete auth url
    @wire(getCompleteUrlForAuthCode, {})
    wiredUrlForAuthCode(result){
        if(result && result.data && result.data.isSuccess)
        {
            this.urlForAuthCode = result.data.completeUrlForAuthCode;
        }
    }


    // called when user clicks the "AUthorize QuickBooks" 
    handleAuthorizeQuickBooksClick(event){
        debugger;
        if(this.urlForAuthCode)
        {
            console.log(`this.urlForAuthCode = ${this.urlForAuthCode}`);
            window.location.href = this.urlForAuthCode;
        }
    }


    recalculatePagination(event){
        this.isLoaded = false;
        debugger;
        if(this.allProductsFromSf && this.allProductsFromSf.length > 0)
        {
            this.totalRecords = this.allProductsFromSf.length; //  total records

            let pageSizeCount = this.defaultPageSize;
            if(this.template.querySelector('lightning-combobox[data-id="pageSizeSelector"]'))
            {
                pageSizeCount = this.template.querySelector('lightning-combobox[data-id="pageSizeSelector"]').value
            }
            this.totalPages = Math.ceil(this.totalRecords / Number(pageSizeCount));
            const startIndex = (this.currentPageNumber - 1)*Number(pageSizeCount); // Basicaly it is the count of records before the first record on current page For Page 1, it will be 0 for Page 2, it will be 10.
            const endIndex = startIndex + Number(pageSizeCount); // The slice() method selects from a given start, up to a (not inclusive) given end.

            // logic for disabling/enabling the PREV and FIRST buttons
            if(this.currentPageNumber == 1)
            {
                this.shouldBackwardNavigationBeDiabled = true;
            }
            else
            {
                this.shouldBackwardNavigationBeDiabled = false;
            }


            // logic for disabling/enabling the NEXT and LAST buttons
            if(this.currentPageNumber == this.totalPages)
            {
                this.shouldForwardNavigationBeDiabled = true;
            }
            else
            {
                this.shouldForwardNavigationBeDiabled = false;
            }

            // SHowing Page 1 of 5 details
            this.currentPageNumberDetails = `Showing Page ${this.currentPageNumber} of ${this.totalPages}`;

            this.paginatedRecords = this.allProductsFromSf.slice(startIndex, endIndex);

            let i=1;
            this.paginatedRecordsWithSno = this.paginatedRecords.map(rec => {
                                                                       
                                                                let Sno =  startIndex + i;
                                                                let Id = rec.Id;
                                                                let Name = rec.Name;
                                                                let ProductCode = rec.ProductCode;
                                                                let Description = rec.Description;
                                                                let IsActive = rec.IsActive;
                                                                let CreatedDate = rec.CreatedDate;
                                                                let Is_Synced_With_QuickBooks__c = rec.Is_Synced_With_QuickBooks__c;
                                                                let QuickBooks_Id__c = rec.QuickBooks_Id__c;
                                                                i++;
                                                                return {Sno, Id, Name, ProductCode, Description, IsActive, CreatedDate, Is_Synced_With_QuickBooks__c, QuickBooks_Id__c};
                                                                        
                                                            });

        }
        this.isLoaded = true;
    }


    handlePageSizeChange(event){
        
        //this.pageSize = event.target.value;
        this.currentPageNumber = 1;
        this.recalculatePagination();
    }

    handleFirstPageClick(){
        this.currentPageNumber = 1;
        this.recalculatePagination();
    }

    handlePreviousPageClick(){
        this.currentPageNumber--;
        this.recalculatePagination();
    }

    handleNextPageClick(){
        this.currentPageNumber++;
        this.recalculatePagination();
    }

    handleLastPageClick(){
        this.currentPageNumber = this.totalPages;
        this.recalculatePagination();
    }

    async handleSyncClick(event){
        debugger;
        const productsTable = this.template.querySelector('lightning-datatable[data-id = "productsTable"]');

        if(productsTable)
        {
            const selectedRows = productsTable.getSelectedRows();            

            if(selectedRows.length > 0)
            {
                // check if selected rows have already been synced
                const alreadySyncedRowsList = selectedRows.filter(eachRow => eachRow.Is_Synced_With_QuickBooks__c == true);

                if(alreadySyncedRowsList && alreadySyncedRowsList.length > 0)
                {
                    Toast.show({
                        label: 'Error',
                        message: 'Please unselect the products that have already been synced. Synced Products: '+ Array.from(alreadySyncedRowsList.map(eachRow => eachRow.Name)).join(','),
                        variant: 'error',
                        mode: 'sticky'
                    }, this);
                    return;
                }
                
                
                const selectedProductsIds = selectedRows.map(eachRow => eachRow.Id);
                debugger;
                console.log(`selectedProductsIds = ${selectedProductsIds}`);
                
                try
                {
                    const response = await syncProductsInQuickBooks({productsIdsToSync:selectedProductsIds, useNamedCredentails:this.useNamedCredentials});
                    console.log(`response = ${JSON.stringify(response)}`);
                    if(response && response.isSuccess)
                    {
                        this.selectedRowsInTable = [];
                        this.fetchProductsFromSF('handleSyncClick');        
                        Toast.show({
                                label: 'Success',
                                message: response.successMessage,
                                variant: 'success',
                                mode: 'dismissable'
                        },this);
                    }
                }
                catch(error)
                {
                    Toast.show({
                        label: 'Error',
                        message: error.body.message,
                        variant: "error",
                        mode:"dismissible"
                    }, this);
                }
                
            }
            else
            {
                Toast.show({
                      label: 'Error',
                      message: 'Please select at least one product to sync',
                      variant: 'error',
                      mode: 'dismissable'
                }, this);
            }
        }

    }


    handleRefreshClick(event){

        this.fetchProductsFromSF('handleRefreshClick');        
    }

}