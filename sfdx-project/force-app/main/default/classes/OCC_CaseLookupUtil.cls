public with sharing class OCC_CaseLookupUtil {

    // Strips everything but digits, then strips leading zeros, so a caller-spoken
    // "1026" matches a stored CaseNumber of "00001026". Voice input never includes
    // the zero-padding a human wouldn't naturally say.
    public static String normalize(String raw) {
        if (raw == null) {
            return '';
        }
        String digitsOnly = raw.replaceAll('[^0-9]', '');
        if (digitsOnly.length() == 0) {
            return '';
        }
        Integer i = 0;
        while (i < digitsOnly.length() - 1 && digitsOnly.substring(i, i + 1) == '0') {
            i++;
        }
        return digitsOnly.substring(i);
    }

    // Returns the Contact Id only when the email matches a Contact AND the identifier matches one
    // of that Contact's own orders or cases; otherwise null. Used by actions that act on the caller
    // as a whole (list cases, open a case) rather than on one record, so email alone is never
    // enough to see or create anything.
    public static Id verifiedContactId(String email, String identifier) {
        String cleanEmail = email == null ? '' : email.trim();
        String normalizedId = normalize(identifier);
        if (String.isBlank(cleanEmail) || normalizedId == '') {
            return null;
        }

        List<Contact> contacts = [SELECT Id FROM Contact WHERE Email = :cleanEmail WITH USER_MODE LIMIT 1];
        if (contacts.isEmpty()) {
            return null;
        }
        Id contactId = contacts[0].Id;

        for (Order__c o : [SELECT Order_Number__c FROM Order__c WHERE Contact__c = :contactId WITH USER_MODE]) {
            if (normalize(o.Order_Number__c) == normalizedId) {
                return contactId;
            }
        }
        for (Case c : [SELECT CaseNumber FROM Case WHERE ContactId = :contactId WITH USER_MODE]) {
            if (normalize(c.CaseNumber) == normalizedId) {
                return contactId;
            }
        }
        return null;
    }

    // Identity lock. The agent binds each lookup's lockedEmail input to the email verified by the
    // first successful lookup of the conversation (empty until then). Enforcing it here rather than
    // in the prompt means the model cannot query a second customer, whatever it is told.
    public static final String LOCK_REFUSAL = 'For your security, I can only help with the account '
        + 'verified in this conversation. Please start a new conversation to check another account.';

    public static String lockOf(String lockedEmail) {
        return String.isBlank(lockedEmail) ? null : lockedEmail.trim();
    }

    public static Boolean violatesLock(String lockedEmail, String email) {
        String lock = lockOf(lockedEmail);
        return lock != null && !lock.equalsIgnoreCase(email == null ? '' : email.trim());
    }
}
