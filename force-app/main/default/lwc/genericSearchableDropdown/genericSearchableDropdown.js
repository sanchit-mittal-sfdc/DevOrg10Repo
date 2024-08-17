import { LightningElement, api } from 'lwc';

export default class GenericSearchableDropdown extends LightningElement {

    @api dropdownOptions;
    @api dropdownOptionsOriginalSet;
    filteredOptions = [];
    areDropdownValuesVisible = false;
    selectedOptionValue;

    

    // this is called onfocus when user clicks/taps on input box
    showDropdownOptions(){
        this.areDropdownValuesVisible = true;
    }

    // this is called onblur when focus is out
    hideDropdownOptions(){
        this.areDropdownValuesVisible = false;
    }

    // this is called when user starts typing in inout box i.e. onchange to filter out options
    doFiltering(event){
        debugger;
        this.dropdownOptions = this.dropdownOptionsOriginalSet;
        let searchString = event.target.value;

        if( searchString && searchString.length > 0 )
        {
            this.dropdownOptions = this.dropdownOptions.filter(option=>{
                if(option.label.toLowerCase().includes(event.target.value.toLowerCase()))
                    return option;
            });
        }
        else
        {
            this.dropdownOptions = this.dropdownOptionsOriginalSet;
        }
    }

    // this is called when the user selects an option from the dropdown
    handleOptionSelection(event){
        debugger;

        // hide the dropdown values after the user selects one value
        this.areDropdownValuesVisible = false;

        const inputComp = this.template.querySelector('lightning-input');
        const selectedOptionLabel = event.currentTarget.dataset.optionlabel;
        const selectedOptionValue = event.currentTarget.dataset.optionvalue;
        const detailInfo = {selectedOptionLabel, selectedOptionValue};

        if(inputComp){
            inputComp.value = `${selectedOptionLabel} (${selectedOptionValue})`;

            this.dispatchEvent( new CustomEvent('optionselected', {detail: detailInfo} ) ); 
        }

        // fire an event with the details of the selected option so that parent component can handle this event to get the selected value.

        console.log(`handleOptionSelection called with value= ${event.currentTarget.optionvalue}`); // VIMP COncept: event.currentTarget will point to div where we have the data-* attributes . while event.target can be the <li> inside <div> hence will return undefined so usigng currentTarget.
        //alert(`handleOptionSelection called with value= ${event.currentTarget.dataset.optionvalue}`);
    }


}