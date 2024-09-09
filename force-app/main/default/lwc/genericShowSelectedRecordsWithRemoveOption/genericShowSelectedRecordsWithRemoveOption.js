import { LightningElement, api } from 'lwc';

export default class GenericShowSelectedRecordsWithRemoveOption extends LightningElement {

    @api selectedRecords; //[{id:'1', label: 'xyz'}, {id:'2', 'label': 'abc'}]
    
}