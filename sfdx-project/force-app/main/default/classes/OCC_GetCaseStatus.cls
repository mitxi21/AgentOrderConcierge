public with sharing class OCC_GetCaseStatus {

    public class Request {
        @InvocableVariable(label='Customer Email' description='Email address the caller provided for verification.' required=true)
        public String email;

        @InvocableVariable(label='Case Number' description='The case number the caller provided, spoken digits only - leading zeros are handled automatically.' required=true)
        public String caseNumber;
        @InvocableVariable(label='Locked Email' description='Email verified earlier in this conversation, bound by the agent - never asked from the caller. When set, any other email is refused.')
        public String lockedEmail;
    }

    public class Response {
        @InvocableVariable(label='Found' description='True if a matching case was located.')
        public Boolean found;

        @InvocableVariable(label='Status' description='Current case status.')
        public String status;

        @InvocableVariable(label='Subject' description='The case subject.')
        public String subject;

        @InvocableVariable(label='Priority' description='The case priority.')
        public String priority;

        @InvocableVariable(label='Open Related Case Count' description='Number of this caller\'s other open cases - a signal for repeated-complaint escalation.')
        public Integer openRelatedCaseCount;

        @InvocableVariable(label='Message' description='Human-readable summary or not-found explanation - safe to relay to the customer as-is.')
        public String message;

        @InvocableVariable(label='Verified Email' description='The email that matched this lookup. Empty when nothing matched. The agent locks the conversation to it.')
        public String verifiedEmail;

        @InvocableVariable(label='Identity Locked' description='True once this conversation is pinned to a verified email.')
        public Boolean identityLocked;
    }

    @InvocableMethod(label='Get Case Status' description='Looks up a support case by case number, verified against the caller\'s email. Returns status, subject, priority, and a signal for repeat contacts.' category='Order Case Concierge')
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
            String normalizedInput = OCC_CaseLookupUtil.normalize(req.caseNumber);

            List<Contact> contacts = [SELECT Id FROM Contact WHERE Email = :email WITH USER_MODE LIMIT 1];
            if (contacts.isEmpty()) {
                resp.found = false;
                resp.message = 'No customer was found with that email.';
                return resp;
            }

            List<Case> cases = [
                SELECT CaseNumber, Status, Subject, Priority
                FROM Case
                WHERE ContactId = :contacts[0].Id
                WITH USER_MODE
            ];

            Case matched = null;
            for (Case c : cases) {
                if (OCC_CaseLookupUtil.normalize(c.CaseNumber) == normalizedInput) {
                    matched = c;
                }
            }

            if (matched == null) {
                resp.found = false;
                resp.message = 'No case was found matching that email and case number.';
                return resp;
            }

            Integer openOthers = 0;
            for (Case c : cases) {
                if (c.Id != matched.Id && c.Status != 'Closed') {
                    openOthers++;
                }
            }

            resp.found = true;
            resp.verifiedEmail = email;
            resp.status = matched.Status;
            resp.subject = matched.Subject;
            resp.priority = matched.Priority;
            resp.openRelatedCaseCount = openOthers;
            resp.message = 'Case ' + matched.CaseNumber + ' is currently ' + matched.Status + '.';
            return resp;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'OCC_GetCaseStatus failed: ' + e.getMessage() + '\n' + e.getStackTraceString());
            resp.found = false;
            resp.message = 'I\'m having trouble looking up that case right now.';
            return resp;
        }
    }
}
