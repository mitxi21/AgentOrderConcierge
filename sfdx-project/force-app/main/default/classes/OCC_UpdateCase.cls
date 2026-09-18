public with sharing class OCC_UpdateCase {

    public class Request {
        @InvocableVariable(label='Customer Email' description='Email address the caller provided for verification.' required=true)
        public String email;

        @InvocableVariable(label='Case Number' description='The case number the caller provided.' required=true)
        public String caseNumber;

        @InvocableVariable(label='Comment' description='The customer\'s note to add to the case.' required=true)
        public String comment;
    }

    public class Response {
        @InvocableVariable(label='Success' description='True if the comment was added.')
        public Boolean success;

        @InvocableVariable(label='Message' description='Human-readable result - safe to relay to the customer as-is.')
        public String message;
    }

    @InvocableMethod(label='Update Case' description='Appends a customer-provided note to an existing case as a case comment. Never changes case status, priority, or ownership.' category='Order Case Concierge')
    public static List<Response> run(List<Request> requests) {
        List<Response> results = new List<Response>();
        for (Request req : requests) {
            results.add(addComment(req));
        }
        return results;
    }

    private static Response addComment(Request req) {
        Response resp = new Response();
        try {
            String email = req.email == null ? '' : req.email.trim();
            String normalizedInput = OCC_CaseLookupUtil.normalize(req.caseNumber);

            List<Contact> contacts = [SELECT Id FROM Contact WHERE Email = :email WITH USER_MODE LIMIT 1];
            if (contacts.isEmpty()) {
                resp.success = false;
                resp.message = 'No customer was found with that email.';
                return resp;
            }

            List<Case> cases = [
                SELECT CaseNumber
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
                resp.success = false;
                resp.message = 'No case was found matching that email and case number.';
                return resp;
            }

            if (String.isBlank(req.comment)) {
                resp.success = false;
                resp.message = 'No comment text was provided.';
                return resp;
            }

            CaseComment cc = new CaseComment(
                ParentId = matched.Id,
                CommentBody = req.comment,
                IsPublished = true
            );
            insert as user cc;

            resp.success = true;
            resp.message = 'Your note was added to case ' + matched.CaseNumber + '.';
            return resp;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'OCC_UpdateCase failed: ' + e.getMessage() + '\n' + e.getStackTraceString());
            resp.success = false;
            resp.message = 'I\'m having trouble adding that note right now.';
            return resp;
        }
    }
}
