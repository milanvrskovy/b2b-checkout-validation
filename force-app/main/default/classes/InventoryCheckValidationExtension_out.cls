public class InventoryCheckValidationExtension_out implements ICheckoutValidator_mp {

    private static final Map<String, Integer> INVENTORY_MAP = new Map<String, Integer>{
        'LCTP1' => 100,
        'LCTP2' => 50,
        'LCTP3' => 25
    };

    private static final String
        MSG_ITEM_INVENTORY_INSUFFICIENT = '{0} inventory: {1}, order item quantity: {2}';

    public static List<String> validate(Order order){
        final List<String> itemValidationMessageList = new List<String>();
        for (OrderItem item: order.OrderItems){
            if (INVENTORY_MAP.containsKey(item.Product2.ProductCode) && item.Quantity > INVENTORY_MAP.get(item.Product2.ProductCode)){
                itemValidationMessageList.add(
                    String.format(MSG_ITEM_INVENTORY_INSUFFICIENT, new List<String>{
                        item.Product2.Name,
                        String.valueOf(INVENTORY_MAP.get(item.Product2.ProductCode)),
                        String.valueOf(item.Quantity)
                    })
                );
            }
        }
        return itemValidationMessageList;
    }
}