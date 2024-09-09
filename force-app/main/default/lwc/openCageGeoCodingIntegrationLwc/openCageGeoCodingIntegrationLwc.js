import { LightningElement } from 'lwc';
import {NavigationMixin} from 'lightning/navigation';

export default class OpenCageGeoCodingIntegrationLwc extends NavigationMixin(LightningElement) {

    openAccountsTab(){
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Account',
                actionName: 'list'
            }
        });
    }
}