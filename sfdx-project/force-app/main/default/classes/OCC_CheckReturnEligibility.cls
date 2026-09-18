public with sharing class OCC_CheckReturnEligibility {

    public class Request {
        @InvocableVariable(label='Customer Email' description='Email address the caller provided for verification.' required=true)
        public String email;

        @InvocableVariable(label='Order Number' description='The order number the caller provided.' required=true)
        public String orderNumber;
        @InvocableVariable(label='Locked Email' description='Email verified earlier in this conversation, bound by the agent - never asked from the caller. When set, any other email is refused.')
        public String lockedEmail;
    }

    public class Response {
        @InvocableVariable(label='Found' description='True if a matching order was located.')
        public Boolean found;

        @InvocableVariable(label='Eligible' description='True if the order is eligible for return.')
        public Boolean eligible;

        @InvocableVariable(label='Reason' description='One-line reason for the eligibility result.')
        public String reason;

        @InvocableVariable(label='Message' description='Human-readable summary - safe to relay to the customer as-is.')
        public String message;

        @InvocableVariable(label='Verified Email' description='The email that matched this lookup. Empty when nothing matched. The agent locks the conversation to it.')
        public String verifiedEmail;

        @InvocableVariable(label='Identity Locked' description='True once this conversation is pinned to a verified email.')
        public Boolean identityLocked;
    }

    @InvocableMethod(label='Check Return Eligibility' description='Checks whether an order is eligible for return, verified against the caller\'s email, and returns a one-line reason.' category='Order Case Concierge')
    public static List<Response> run(List<Request> requests) {
        List<Response> results = new List<Response>();
        for (Request req : requests) {
            Response r = check(req);
            r.identityLocked = String.isNotBlank(r.verifiedEmail);
            results.add(r);
        }
        return results;
    }

    private static Response check(Request req) {
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
                resp.eligible = false;
                resp.reason = 'not found';
                resp.message = 'No customer was found with that email, so eligibility can\'t be checked.';
                return resp;
            }

            List<Order__c> orders = [
                SELECT Order_Number__c, Return_Eligible__c
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
                resp.eligible = false;
                resp.reason = 'not found';
                resp.message = 'No order was found matching that email and order number, so eligibility can\'t be checked.';
                return resp;
            }

            resp.found = true;
            resp.verifiedEmail = email;
            resp.eligible = matched.Return_Eligible__c;
            if (matched.Return_Eligible__c) {
                resp.reason = 'within the standard return window';
                resp.message = 'That order is eligible for return - it\'s within the standard return window.';
            } else {
                resp.reason = 'outside the standard return window';
                resp.message = 'That order is not eligible for return - it\'s outside the standard return window.';
            }
            return resp;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'OCC_CheckReturnEligibility failed: ' + e.getMessage() + '\n' + e.getStackTraceString());
            resp.found = false;
            resp.eligible = false;
            resp.reason = 'error';
            resp.message = 'I\'m having trouble checking that right now.';
            return resp;
        }
    }
}
