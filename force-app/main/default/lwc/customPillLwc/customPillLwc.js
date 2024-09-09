import { LightningElement, api } from 'lwc';

export default class CustomPillLwc extends LightningElement {
    
    @api pillDetails;


    handleRemove(event){
        console.log(`handleRemove called for pill label ${this.pillLabel} and pillId ${this.pillId}`);

        /* V. Imp concept of bubble:true and composed:true . plz refer the notes for it
        * why i have used bubbles: true, composed:true? so that this even can be handled directly in the 
        grand parent component i.e. where you have instatiated genericShowSleectedRecordsWithRemoveOption. 
        Otherwise I'd have to handle it in parent then fire another event to handle it in grand parent
        */
        const removePillEvent = new CustomEvent('removepill', {detail : this.pillDetails, bubbles: true, composed:true});
        if(removePillEvent)
        {
            this.dispatchEvent(removePillEvent);
        }
    }
}