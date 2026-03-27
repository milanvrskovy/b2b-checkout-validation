import { LightningElement, api, track } from 'lwc';
import validateOrder from '@salesforce/apex/CheckoutValidationController_mp.validateOrder';

export default class CheckoutValidation_mp extends LightningElement {

    @api recordId;;

    @track response;
    isLoading = false;
    hasValidated = false;

    /**
     * Triggers the validation pipeline via Apex controller.
     * Manages loading state and stores the response for rendering.
     */
    async handleValidate() {
        this.isLoading = true;
        this.hasValidated = false;
        this.response = null;
        try {
            this.response = await validateOrder({ orderId: this.recordId });
            this.hasValidated = true;
        } catch (error) {
            this.response = {
                isValid: false,
                messages: [error.body?.message ?? 'An unexpected error occurred.']
            };
            this.hasValidated = true;
        } finally {
            this.isLoading = false;
        }
    }

    /** True when validation has run and there are error messages to display. */
    get hasMessages() {
        return this.hasValidated && this.response?.messages?.length > 0;
    }

    /** True when validation has run and the order passed all rules. */
    get isSuccess() {
        return this.hasValidated && this.response?.isValid === true;
    }
}