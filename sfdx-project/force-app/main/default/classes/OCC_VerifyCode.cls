/**
 * Phase 16 - step 2 of the email verification gate.
 *
 * Checks the six-digit code the caller read back against the newest unexpired OCC_Verification__c
 * row for that address. Only this action can set verified = true, so the agent script's gate is a
 * fact about the org, not a promise in a prompt.
 *
 * Defence in depth: this proves the caller owns the address. OCC_CaseLookupUtil.violatesLock then
 * pins the rest of the conversation to it, and USER_MODE plus the least-privilege permset limit
 * what could be read even if both were bypassed.
 */
public with sharing class OCC_VerifyCode {

    @TestVisible private static final Integer MAX_ATTEMPTS = 5;

    public class Request {
        @InvocableVariable(required=true label='Email' description='The email address the code was sent to')
        public String email;
        @InvocableVariable(required=true label='Code' description='The six-digit code the caller read back')
        public String code;
    }

    public class Response {
        @InvocableVariable(label='Verified' description='True only when the code matched an unexpired code for that address')
        public Boolean verified;
        @InvocableVariable(label='Message' description='Message to read to the caller verbatim')
        public String message;
        @InvocableVariable(label='Verified Email' description='The address now verified for this conversation')
        public String verifiedEmail;
    }

    @InvocableMethod(
        label='Verify Code'
        description='Checks the six-digit code the caller read back. Only a correct, unexpired code verifies the caller.'
        category='Order Case Concierge')
    public static List<Response> run(List<Request> requests) {
        List<Response> results = new List<Response>();
        for (Request req : requests) {
            results.add(verify(req));
        }
        return results;
    }

    private static Response verify(Request req) {
        Response resp = new Response();
        resp.verified = false;
        resp.verifiedEmail = '';
        try {
            String email = req.email == null ? '' : req.email.trim();
            String code = req.code == null ? '' : req.code.replaceAll('[^0-9]', '');

            if (String.isBlank(email) || String.isBlank(code)) {
                resp.message = 'I need the six-digit code from that email before I can continue.';
                return resp;
            }

            List<OCC_Verification__c> rows = [
                SELECT Id, Code_Hash__c, Expires_At__c, Attempts__c, Verified__c, Verified_Email__c
                FROM OCC_Verification__c
                WHERE Verified_Email__c = :email
                WITH USER_MODE
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (rows.isEmpty()) {
                resp.message = 'I do not have a code outstanding for that address. Shall I send a new one?';
                return resp;
            }

            OCC_Verification__c row = rows[0];

            if (row.Expires_At__c == null || row.Expires_At__c < System.now()) {
                resp.message = 'That code has expired. Shall I send you a new one?';
                return resp;
            }
            if (row.Attempts__c != null && row.Attempts__c >= MAX_ATTEMPTS) {
                resp.message = 'There have been too many incorrect attempts for that code. Shall I send you a new one?';
                return resp;
            }

            row.Attempts__c = (row.Attempts__c == null ? 0 : row.Attempts__c) + 1;

            if (row.Code_Hash__c == OCC_SendVerificationCode.hash(code, email)) {
                row.Verified__c = true;
                update as user row;
                resp.verified = true;
                resp.verifiedEmail = email;
                resp.message = 'Thank you, that code is correct - you are verified.';
                return resp;
            }

            update as user row;
            Integer left = MAX_ATTEMPTS - Integer.valueOf(row.Attempts__c);
            resp.message = left > 0
                ? 'That code does not match. Please read it back to me once more.'
                : 'That code does not match, and there have been too many attempts. Shall I send you a new one?';
            return resp;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'OCC_VerifyCode failed: ' + e.getMessage());
            resp.message = 'I am not able to check that code right now.';
            return resp;
        }
    }
}
