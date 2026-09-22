public with sharing class OCC_CreateEscalationCase {

    public class Request {
        @InvocableVariable(label='Customer Email' description='Email address the caller provided, if known - may be blank when identity can\'t be verified.')
        public String email;

        @InvocableVariable(label='Summary' description='Structured summary: what the customer asked for, what was already checked, and why this is being escalated.' required=true)
        public String summary;

        @InvocableVariable(label='Reason Code' description='Why this is being escalated: financial_request, unverifiable_identity, frustration, or out_of_scope.' required=true)
        public String reasonCode;
    }

    public class Response {
        @InvocableVariable(label='Case Number' description='The case number of the newly created escalation case.')
        public String caseNumber;

        @InvocableVariable(label='Message' description='Human-readable confirmation, including a rough follow-up timeframe - safe to relay to the customer as-is.')
        public String message;
    }

    private static final String FOLLOWUP_TIMEFRAME = 'within 1 business day';

    /**
     * Reason codes are how the model classifies an escalation; they are not what a service team
     * should read. Each maps to the Subject, Type and Reason a human agent would have typed, so a
     * Case looks like any other in the queue. The model-facing codes are unchanged.
     * Shared with scripts/rename_agent_cases.apex, so both name Cases the same way.
     */
    public static final String AGENT_ORIGIN = 'Agentforce Agent';
    private static final Map<String, List<String>> NAMING = new Map<String, List<String>>{
        // reason code           => { Subject, Type, Reason }
        'financial_request'     => new List<String>{ 'Refund request', 'Billing', 'Refund request' },
        'unverifiable_identity' => new List<String>{ 'Unable to verify caller identity', 'Account', 'Identity verification' },
        'frustration'           => new List<String>{ 'Repeat contact - unresolved issue', 'Support', 'Customer dissatisfaction' },
        'out_of_scope'          => new List<String>{ 'Request outside supported scope', 'Account', 'Out of scope request' }
    };
    // Anything unrecognised, including a blank code and the retired 'unlogged_escalation'.
    private static final List<String> FALLBACK_NAMING =
        new List<String>{ 'Customer escalation', 'Support', 'Other' };

    /**
     * A Case carrying only the naming fields for a reason code. Callers add their own data.
     */
    public static Case named(String reasonCode) {
        String key = reasonCode == null ? '' : reasonCode.trim().toLowerCase();
        List<String> naming = NAMING.containsKey(key) ? NAMING.get(key) : FALLBACK_NAMING;
        return new Case(Subject = naming[0], Type = naming[1], Reason = naming[2], Origin = AGENT_ORIGIN);
    }

    @InvocableMethod(label='Create Escalation Case' description='Creates a Case for human follow-up with a structured summary and High priority. Use for anything financial, unverifiable, or emotionally charged.' category='Order Case Concierge')
    public static List<Response> run(List<Request> requests) {
        List<Response> results = new List<Response>();
        for (Request req : requests) {
            results.add(escalate(req));
        }
        return results;
    }

    private static Response escalate(Request req) {
        Response resp = new Response();
        try {
            Id contactId = null;
            if (String.isNotBlank(req.email)) {
                List<Contact> contacts = [SELECT Id FROM Contact WHERE Email = :req.email.trim() WITH USER_MODE LIMIT 1];
                if (!contacts.isEmpty()) {
                    contactId = contacts[0].Id;
                }
            }

            Case escalationCase = named(req.reasonCode);
            escalationCase.Priority = 'High';
            escalationCase.Escalation_Summary__c = req.summary;
            escalationCase.ContactId = contactId;
            insert as user escalationCase;

            Case created = [SELECT CaseNumber FROM Case WHERE Id = :escalationCase.Id WITH USER_MODE LIMIT 1];
            resp.caseNumber = created.CaseNumber;
            resp.message = 'A team member will follow up ' + FOLLOWUP_TIMEFRAME + ' - your case number is ' + created.CaseNumber + '.';
            return resp;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'OCC_CreateEscalationCase failed: ' + e.getMessage() + '\n' + e.getStackTraceString());
            resp.caseNumber = null;
            resp.message = 'I wasn\'t able to log this automatically, but please hold while I connect you to a team member.';
            return resp;
        }
    }
}
