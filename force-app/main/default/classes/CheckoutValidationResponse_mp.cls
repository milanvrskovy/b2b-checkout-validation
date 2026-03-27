public with sharing class CheckoutValidationResponse_mp {

    @AuraEnabled public Boolean isValid;
    @AuraEnabled public List<String> messages;

    public CheckoutValidationResponse_mp(Boolean isValid, List<String> messages) {
        this.isValid = isValid;
        this.messages = messages;
    }
}