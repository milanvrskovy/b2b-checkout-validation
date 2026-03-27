public with sharing class CustomCheckoutValidationsSelector_mp {

    public static List<CustomCheckoutValidation__c> selectActiveValidations() {
        return [
            SELECT
                Id,
                Name,
                RecordType.DeveloperName,
                ApexClassName__c,
                FlowApiName__c,
                ValidatedField__c,
                ValidationOperator__c,
                ValidationValue__c,
                Message__c
            FROM CustomCheckoutValidation__c
            WHERE Active__c = true
            WITH SECURITY_ENFORCED
        ];
    }
}