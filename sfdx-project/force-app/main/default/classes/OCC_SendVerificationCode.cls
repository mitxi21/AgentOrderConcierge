/**
 * Phase 16 - step 1 of the email verification gate.
 *
 * Emails a six-digit code to the address the caller claims, and stores only a salted SHA-256 hash
 * of it on an OCC_Verification__c row. The code is never returned to the agent and never spoken:
 * the only way to learn it is to open the mailbox, which is the whole point.
 *
 * The single exception is Keyburn_Setting__mdt.Test_Mode__c. While that is true no email is sent and
 * the code is stored in plain text on the row. This is a Developer Edition trade-off: the org sends
 * without domain authentication, so Proton flags the mail as failing its checks, and it allows only
 * 15 single emails a day - which the eval suites would exhaust in one run. The demo therefore reads
 * the code from the verification record too, and shows a captured email as proof of the real path.
 * In production this flag stays false and the code exists only in the caller's mailbox.
 *
 * Demo routing: an @example.com address is sent to a plus-alias of Keyburn_Setting__mdt.Demo_Inbox__c
 * (jane.doe@example.com -> keyburn.demo+jane.doe@proton.me), so one mailbox receives every code while
 * the sample data keeps its original addresses.
 */
public with sharing class OCC_SendVerificationCode {

    @TestVisible private static final Integer CODE_TTL_MINUTES = 10;

    public class Request {
        @InvocableVariable(required=true label='Email' description='The email address the caller says is theirs')
        public String email;
        @InvocableVariable(label='Locked Email' description='Email already verified in this conversation, bound by the agent. When set, a code is never issued for a different address.')
        public String lockedEmail;
    }

    public class Response {
        @InvocableVariable(label='Sent' description='True when a code was emailed')
        public Boolean sent;
        @InvocableVariable(label='Message' description='Message to read to the caller verbatim')
        public String message;
        @InvocableVariable(label='Claimed Email' description='The address the code was issued for')
        public String claimedEmail;
    }

    @InvocableMethod(
        label='Send Verification Code'
        description='Emails a six-digit verification code to the address the caller claims, so they can prove they own it. Never reveals the code.'
        category='Order Case Concierge')
    public static List<Response> run(List<Request> requests) {
        List<Response> results = new List<Response>();
        for (Request req : requests) {
            results.add(send(req));
        }
        return results;
    }

    private static Response send(Request req) {
        Response resp = new Response();
        resp.sent = false;
        try {
            String email = req.email == null ? '' : req.email.trim();
            resp.claimedEmail = email;
            if (String.isBlank(email) || !email.contains('@')) {
                resp.message = 'I need the email address on your order before I can send a code.';
                return resp;
            }

            // Once the conversation is pinned to a customer, a second address gets no code at all.
            // Without this the agent announces "I have sent a code to <other address>" and only
            // refuses on the following turn - and anyone could use the gate to post codes at an
            // address they do not own.
            if (OCC_CaseLookupUtil.violatesLock(req.lockedEmail, email)) {
                resp.message = OCC_CaseLookupUtil.LOCK_REFUSAL;
                return resp;
            }

            // An unknown address gets the same answer as a known one: whether an address exists in
            // Keyburn's data is not something an unverified caller may learn.
            List<Contact> contacts = [
                SELECT Id, FirstName, Email FROM Contact WHERE Email = :email WITH USER_MODE LIMIT 1
            ];

            String code = generateCode();
            Boolean testMode = testMode();
            OCC_Verification__c v = new OCC_Verification__c(
                Contact__c = contacts.isEmpty() ? null : contacts[0].Id,
                Code_Hash__c = hash(code, email),
                // Eval only: a Developer Edition org allows 15 single emails a day, so a suite run
                // cannot send real ones, and the code is otherwise only in the mailbox.
                Code_Plain__c = testMode ? code : null,
                Expires_At__c = System.now().addMinutes(CODE_TTL_MINUTES),
                Attempts__c = 0,
                Verified__c = false,
                Verified_Email__c = email,
                Sent_To__c = routeAddress(email)
            );
            insert as user v;

            if (!contacts.isEmpty() && !testMode) {
                sendEmail(v.Sent_To__c, contacts[0].FirstName, code);
            }

            resp.sent = true;
            resp.message = 'I have sent a six-digit code to that address. It is valid for '
                + CODE_TTL_MINUTES + ' minutes - please read it back to me when it arrives.';
            return resp;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'OCC_SendVerificationCode failed: ' + e.getMessage());
            resp.message = 'I am not able to send a verification code right now.';
            return resp;
        }
    }

    /** Demo mailbox routing: name@example.com -> demoinbox+name@domain. Real addresses are untouched. */
    @TestVisible
    private static String routeAddress(String email) {
        String demoInbox = demoInbox();
        if (String.isBlank(demoInbox) || !email.endsWith('@example.com')) {
            return email;
        }
        String localPart = email.substringBefore('@');
        return demoInbox.substringBefore('@') + '+' + localPart + '@' + demoInbox.substringAfter('@');
    }

    private static String demoInbox() {
        Keyburn_Setting__mdt config = Keyburn_Setting__mdt.getInstance('Default');
        return config == null ? null : config.Demo_Inbox__c;
    }

    /** EVAL ONLY. See Keyburn_Setting__mdt.Test_Mode__c - must be false for the demo. */
    @TestVisible
    private static Boolean testMode() {
        Keyburn_Setting__mdt config = Keyburn_Setting__mdt.getInstance('Default');
        return config != null && config.Test_Mode__c == true;
    }

    private static String generateCode() {
        Integer value = Math.abs(Crypto.getRandomInteger()) - (Math.abs(Crypto.getRandomInteger()) / 1000000) * 1000000;
        return String.valueOf(Math.mod(Math.abs(value), 1000000)).leftPad(6, '0');
    }

    /** Salted with the claimed address, so a hash cannot be replayed against another verification. */
    public static String hash(String code, String email) {
        Blob digest = Crypto.generateDigest('SHA-256', Blob.valueOf(code + '|' + email.toLowerCase()));
        return EncodingUtil.convertToHex(digest);
    }

    private static void sendEmail(String to, String firstName, String code) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ to });
        mail.setSubject('Your Keyburn verification code');
        mail.setPlainTextBody(
            (String.isBlank(firstName) ? 'Hello,' : 'Hello ' + firstName + ',') + '\n\n'
            + 'Your Keyburn verification code is ' + code + '.\n'
            + 'It expires in ' + CODE_TTL_MINUTES + ' minutes. If you did not ask for it, ignore this email.\n\n'
            + 'Keyburn Customer Service'
        );
        mail.setSaveAsActivity(false);
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
    }
}
