// Demo-day dates for the orders used in HumanScript.txt. Idempotent - safe to re-run.
//   sf apex run --file scripts/set_demo_order_dates.apex --target-org devorg
//
// Every demo order is estimated to arrive on DEMO_DATE, so the spoken delivery date is never
// in the past on stage. Order_Date__c is shifted back by that order's original lead time, so
// the gap between ordering and delivery stays the one in sample-data/orders_sample.csv.
// Re-run it (with a new DEMO_DATE) after any Order reload, next to set_demo_geodata.apex.
// Only Shipped demo orders are listed: ORD-1024 (the misheard digit in the voice call) is
// Delivered and belongs to john.smith, so the lookup refuses it and its dates never surface.

Date DEMO_DATE = Date.newInstance(2026, 9, 24);

// order number => lead time in days (Estimated_Delivery__c - Order_Date__c in the sample data)
Map<String, Integer> leadDays = new Map<String, Integer>{
    'ORD-1042' => 6,   // jane.doe   - chat tracking + status + return eligibility
    'ORD-1097' => 3,   // jane.doe   - second tracking answer, no second map card
    'ORD-1088' => 8    // maria.garcia - the identity-lock refusal
};

List<Order__c> orders = [
    SELECT Id, Order_Number__c, Status__c, Order_Date__c, Estimated_Delivery__c
    FROM Order__c WHERE Order_Number__c IN :leadDays.keySet()
];
for (Order__c o : orders) {
    o.Estimated_Delivery__c = DEMO_DATE;
    o.Order_Date__c = DEMO_DATE.addDays(-leadDays.get(o.Order_Number__c));
}
update orders;

for (Order__c o : [
    SELECT Order_Number__c, Status__c, Order_Date__c, Estimated_Delivery__c
    FROM Order__c WHERE Order_Number__c IN :leadDays.keySet() ORDER BY Order_Number__c
]) {
    System.debug(LoggingLevel.ERROR, 'DATES|' + o.Order_Number__c + '|' + o.Status__c
        + '|ordered ' + o.Order_Date__c + '|eta ' + o.Estimated_Delivery__c);
}
System.debug(LoggingLevel.ERROR, 'DATES|orders updated: ' + orders.size() + ' of ' + leadDays.size());
