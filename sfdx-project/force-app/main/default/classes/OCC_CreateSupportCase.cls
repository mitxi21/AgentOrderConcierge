public with sharing class OCC_CreateSupportCase {

    public class Request {
        @InvocableVariable(label='Customer Email' description='Email address the caller provided for verification.' required=true)
        public String email;

        @InvocableVariable(label='Verifying Identifier' description='An order number or case number the caller already confirmed in this conversation - proves the email belongs to them.' required=true)
        public String verifyingIdentifier;

        @InvocableVariable(label='Issue Summary' description='One short sentence, in the caller\'s words, describing what the new case is about.' required=true)
        public String issueSummary;
        @InvocableVariable(label='Locked Email' description='Email verified earlier in this conversation, bound by the agent - never asked from the caller. When set, any other email is refused.')
        public String lockedEmail;
    }

    public class Response {
        @InvocableVariable(label='Success' description='True if the case was created. False means no case was created.')
        public Boolean success;

        @InvocableVariable(label='Case Number' description='The case number of the newly created case.')
        public String caseNumber;

        @InvocableVariable(label='Message' description='Human-readable confirmation including the case number, or why no case was created - safe to relay to the customer as-is.')
        public String message;

        @InvocableVariable(label='Verified Email' description='The email that was verified. Empty when verification failed. The agent locks the conversation to it.')
        public String verifiedEmail;

        @InvocableVariable(label='Identity Locked' description='True once this conversation is pinned to a verified email.')
        public Boolean identityLocked;
    }

    private static final String FOLLOWUP_TIMEFRAME = 'within 2 business days';
    private static final Integer SUBJECT_MAX = 255;

    @InvocableMethod(label='Create Support Case' description='Opens a normal-priority support case for a verified caller who asks for one. Not for escalations - use Create Escalation Case for refunds, frustration, or unverifiable callers.' category='Order Case Concierge')
    public static List<Response> run(List<Request> requests) {
        List<Response> results = new List<Response>();
        for (Request req : requests) {
            Response r = create(req);
            r.identityLocked = String.isNotBlank(r.verifiedEmail);
            results.add(r);
        }
        return results;
    }

    private static Response create(Request req) {
        Response resp = new Response();
        try {
            resp.verifiedEmail = OCC_CaseLookupUtil.lockOf(req.lockedEmail);
            if (OCC_CaseLookupUtil.violatesLock(req.lockedEmail, req.email)) {
                resp.success = false;
                resp.message = OCC_CaseLookupUtil.LOCK_REFUSAL;
                return resp;
            }
            Id contactId = OCC_CaseLookupUtil.verifiedContactId(req.email, req.verifyingIdentifier);
            if (contactId == null) {
                resp.success = false;
                resp.message = 'I couldn\'t verify an account with that email and order or case number, so I haven\'t opened a case.';
                return resp;
            }
            if (String.isBlank(req.issueSummary)) {
                resp.success = false;
                resp.message = 'I need a short description of the issue before I can open a case.';
                return resp;
            }

            // The caller's own words are the subject, as a human agent would type them. Origin
            // marks every Case the agent opens, whatever the channel. No Type is set: this action
            // doesn't know what the issue is about, and guessing one would be worse than a blank.
            Case supportCase = new Case(
                Subject = req.issueSummary.trim().abbreviate(SUBJECT_MAX),
                Priority = 'Medium',
                Origin = OCC_CreateEscalationCase.AGENT_ORIGIN,
                Reason = 'Other',
                ContactId = contactId
            );
            insert as user supportCase;

            Case created = [SELECT CaseNumber FROM Case WHERE Id = :supportCase.Id WITH USER_MODE LIMIT 1];
            resp.success = true;
            resp.verifiedEmail = req.email.trim();
            resp.caseNumber = created.CaseNumber;
            resp.message = 'I\'ve opened case ' + created.CaseNumber + ' for you. A team member will follow up ' + FOLLOWUP_TIMEFRAME + '.';
            return resp;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'OCC_CreateSupportCase failed: ' + e.getMessage() + '\n' + e.getStackTraceString());
            resp.success = false;
            resp.message = 'I wasn\'t able to open a case right now.';
            return resp;
        }
    }
}
