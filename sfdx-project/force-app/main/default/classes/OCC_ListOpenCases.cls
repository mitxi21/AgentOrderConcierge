public with sharing class OCC_ListOpenCases {

    public class Request {
        @InvocableVariable(label='Customer Email' description='Email address the caller provided for verification.' required=true)
        public String email;

        @InvocableVariable(label='Verifying Identifier' description='An order number or case number the caller already confirmed in this conversation - proves the email belongs to them.' required=true)
        public String verifyingIdentifier;
        @InvocableVariable(label='Locked Email' description='Email verified earlier in this conversation, bound by the agent - never asked from the caller. When set, any other email is refused.')
        public String lockedEmail;
    }

    public class Response {
        @InvocableVariable(label='Verified' description='True if the email and identifier matched the same customer. False means nothing was looked up.')
        public Boolean verified;

        @InvocableVariable(label='Open Case Count' description='Number of the caller\'s open cases. Zero means they have none.')
        public Integer openCaseCount;

        @InvocableVariable(label='Message' description='Human-readable summary of the caller\'s open cases, or that they have none - safe to relay to the customer as-is.')
        public String message;

        @InvocableVariable(label='Verified Email' description='The email that was verified. Empty when verification failed. The agent locks the conversation to it.')
        public String verifiedEmail;

        @InvocableVariable(label='Identity Locked' description='True once this conversation is pinned to a verified email.')
        public Boolean identityLocked;
    }

    // Voice answers must stay short; beyond this many cases, give the count and the most recent ones.
    private static final Integer MAX_CASES_SPOKEN = 3;

    @InvocableMethod(label='List Open Cases' description='Lists the verified caller\'s open support cases (case number and subject). Requires email plus an order or case number that belongs to the caller.' category='Order Case Concierge')
    public static List<Response> run(List<Request> requests) {
        List<Response> results = new List<Response>();
        for (Request req : requests) {
            Response r = listCases(req);
            r.identityLocked = String.isNotBlank(r.verifiedEmail);
            results.add(r);
        }
        return results;
    }

    // Escalation cases carry an internal subject ("Agent escalation: financial_request"). The reason
    // code is for the human team, not something to read back to the caller.
    @TestVisible
    private static String spokenSubject(String subject) {
        if (subject != null && subject.startsWith(ESCALATION_SUBJECT_PREFIX)) {
            return 'a request for a team member to follow up';
        }
        return subject;
    }

    private static final String ESCALATION_SUBJECT_PREFIX = 'Agent escalation:';

    private static Response listCases(Request req) {
        Response resp = new Response();
        try {
            resp.verifiedEmail = OCC_CaseLookupUtil.lockOf(req.lockedEmail);
            if (OCC_CaseLookupUtil.violatesLock(req.lockedEmail, req.email)) {
                resp.verified = false;
                resp.message = OCC_CaseLookupUtil.LOCK_REFUSAL;
                return resp;
            }
            Id contactId = OCC_CaseLookupUtil.verifiedContactId(req.email, req.verifyingIdentifier);
            if (contactId == null) {
                resp.verified = false;
                resp.openCaseCount = 0;
                resp.message = 'I couldn\'t verify an account with that email and order or case number.';
                return resp;
            }

            List<Case> openCases = [
                SELECT CaseNumber, Subject
                FROM Case
                WHERE ContactId = :contactId AND IsClosed = false
                WITH USER_MODE
                ORDER BY CreatedDate DESC
            ];

            resp.verified = true;
            resp.verifiedEmail = req.email.trim();
            resp.openCaseCount = openCases.size();
            if (openCases.isEmpty()) {
                resp.message = 'You don\'t have any open cases.';
                return resp;
            }

            List<String> spoken = new List<String>();
            for (Integer i = 0; i < openCases.size() && i < MAX_CASES_SPOKEN; i++) {
                spoken.add('case ' + openCases[i].CaseNumber + ', ' + spokenSubject(openCases[i].Subject));
            }
            String countText = openCases.size() == 1 ? 'one open case' : openCases.size() + ' open cases';
            resp.message = 'You have ' + countText + '. '
                + (openCases.size() > MAX_CASES_SPOKEN ? 'The most recent are ' : '')
                + String.join(spoken, '; ') + '.';
            return resp;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'OCC_ListOpenCases failed: ' + e.getMessage() + '\n' + e.getStackTraceString());
            resp.verified = false;
            resp.openCaseCount = 0;
            resp.message = 'I\'m having trouble looking up your cases right now.';
            return resp;
        }
    }
}
