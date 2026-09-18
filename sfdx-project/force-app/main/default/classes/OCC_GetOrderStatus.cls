public with sharing class OCC_GetOrderStatus {

    public class Request {
        @InvocableVariable(label='Customer Email' description='Email address the caller provided for verification.' required=true)
        public String email;

        @InvocableVariable(label='Order Number' description='The order number the caller provided, e.g. ORD-1042.' required=true)
        public String orderNumber;
        @InvocableVariable(label='Locked Email' description='Email verified earlier in this conversation, bound by the agent - never asked from the caller. When set, any other email is refused.')
        public String lockedEmail;
    }

    public class Response {
        @InvocableVariable(label='Found' description='True if a matching order was located for this email and order number.')
        public Boolean found;

        @InvocableVariable(label='Status' description='Current order status (Draft, Processing, Shipped, Delivered, or Cancelled). Draft means saved but not submitted yet.')
        public String status;

        @InvocableVariable(label='Item' description='The item on the order.')
        public String item;

        @InvocableVariable(label='Order Date' description='The date the order was placed.')
        public String orderDate;

        @InvocableVariable(label='Estimated Delivery' description='The estimated delivery date, if available.')
        public String estimatedDelivery;

        @InvocableVariable(label='Message' description='Human-readable summary or not-found explanation - safe to relay to the customer as-is.')
        public String message;

        @InvocableVariable(label='Verified Email' description='The email that matched this lookup. Empty when nothing matched. The agent locks the conversation to it.')
        public String verifiedEmail;

        @InvocableVariable(label='Identity Locked' description='True once this conversation is pinned to a verified email.')
        public Boolean identityLocked;
    }

    @InvocableMethod(label='Get Order Status' description='Looks up an order by order number, verified against the caller\'s email. Returns status, item, and delivery estimate, or a clear not-found signal.' category='Order Case Concierge')
    public static List<Response> run(List<Request> requests) {
        List<Response> results = new List<Response>();
        for (Request req : requests) {
            Response r = lookup(req);
            r.identityLocked = String.isNotBlank(r.verifiedEmail);
            results.add(r);
        }
        return results;
    }

    private static Response lookup(Request req) {
        Response resp = new Response();
        try {
            resp.verifiedEmail = OCC_CaseLookupUtil.lockOf(req.lockedEmail);
            if (OCC_CaseLookupUtil.violatesLock(req.lockedEmail, req.email)) {
                resp.found = false;
                resp.message = OCC_CaseLookupUtil.LOCK_REFUSAL;
                return resp;
            }
            String email = req.email == null ? '' : req.email.trim();
            String normalizedInput = OCC_CaseLookupUtil.normalize(req.orderNumber);

            List<Contact> contacts = [SELECT Id FROM Contact WHERE Email = :email WITH USER_MODE LIMIT 1];
            if (contacts.isEmpty()) {
                resp.found = false;
                resp.message = 'No customer was found with that email.';
                return resp;
            }

            List<Order__c> orders = [
                SELECT Order_Number__c, Status__c, Item__c, Order_Date__c, Estimated_Delivery__c
                FROM Order__c
                WHERE Contact__c = :contacts[0].Id
                WITH USER_MODE
            ];

            Order__c matched = null;
            for (Order__c ord : orders) {
                if (OCC_CaseLookupUtil.normalize(ord.Order_Number__c) == normalizedInput) {
                    matched = ord;
                }
            }

            if (matched == null) {
                resp.found = false;
                resp.message = 'No order was found matching that email and order number.';
                return resp;
            }

            resp.found = true;
            resp.verifiedEmail = email;
            resp.status = matched.Status__c;
            resp.item = matched.Item__c;
            // ISO yyyy-MM-dd, not Date.format(): format() follows the running user's locale, so the
            // same date reads as 9/11 or 11/09 depending on who runs the action (see project-status,
            // Phase 7). The voice layer also expects ISO for its <date> tags.
            resp.orderDate = matched.Order_Date__c == null ? null : String.valueOf(matched.Order_Date__c);
            resp.estimatedDelivery = matched.Estimated_Delivery__c == null ? null : String.valueOf(matched.Estimated_Delivery__c);
            if (matched.Status__c == 'Draft') {
                // A draft was never placed, so no delivery date is promised even if one is stored.
                resp.estimatedDelivery = null;
                resp.message = 'Order ' + matched.Order_Number__c + ' is saved as a draft and hasn\'t been submitted yet, '
                    + 'so we haven\'t started processing it. Once you place it, it moves to Processing.';
                return resp;
            }
            resp.message = 'Order ' + matched.Order_Number__c + ' is currently ' + matched.Status__c + '.';
            return resp;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'OCC_GetOrderStatus failed: ' + e.getMessage() + '\n' + e.getStackTraceString());
            resp.found = false;
            resp.message = 'I\'m having trouble looking up that order right now.';
            return resp;
        }
    }
}
