public with sharing class OrdersSelector_mp {

    public static List<Order> selectById(Set<Id> orderIdSet) {
        return [
            SELECT
                Id,
                Name,
                Status,
                TotalAmount,
                AccountId,
                Account.Name,
                EffectiveDate,
                BillingCountry,
                ShipToContactId,
                (SELECT Id, Quantity, Product2.Name, Product2.ProductCode FROM OrderItems)
            FROM Order
            WHERE Id IN :orderIdSet
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
    }
}