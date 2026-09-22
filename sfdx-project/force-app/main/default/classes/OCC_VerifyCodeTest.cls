@IsTest
private class OCC_VerifyCodeTest {

    private static final String EMAIL = 'jane.doe@example.com';

    @TestSetup
    static void setup() {
        Account a = new Account(Name = 'Jane Doe');
        insert a;
        insert new Contact(FirstName = 'Jane', LastName = 'Doe', AccountId = a.Id, Email = EMAIL);
    }

    /** The code is never stored, so a test writes its own row with a known code. */
    private static OCC_Verification__c row(String code, Datetime expiresAt, Decimal attempts) {
        OCC_Verification__c v = new OCC_Verification__c(
            Contact__c = [SELECT Id FROM Contact LIMIT 1].Id,
            Code_Hash__c = OCC_SendVerificationCode.hash(code, EMAIL),
            Expires_At__c = expiresAt,
            Attempts__c = attempts,
            Verified__c = false,
            Verified_Email__c = EMAIL
        );
        insert v;
        return v;
    }

    private static OCC_VerifyCode.Response verify(String email, String code) {
        OCC_VerifyCode.Request r = new OCC_VerifyCode.Request();
        r.email = email;
        r.code = code;
        return OCC_VerifyCode.run(new List<OCC_VerifyCode.Request>{ r })[0];
    }

    @IsTest
    static void correctCodeVerifies() {
        OCC_Verification__c v = row('123456', System.now().addMinutes(10), 0);

        Test.startTest();
        OCC_VerifyCode.Response resp = verify(EMAIL, '123456');
        Test.stopTest();

        Assert.isTrue(resp.verified);
        Assert.areEqual(EMAIL, resp.verifiedEmail);
        Assert.isTrue([SELECT Verified__c FROM OCC_Verification__c WHERE Id = :v.Id].Verified__c);
    }

    @IsTest
    static void spokenCodeWithSpacesStillVerifies() {
        row('123456', System.now().addMinutes(10), 0);

        Test.startTest();
        OCC_VerifyCode.Response resp = verify(EMAIL, '1 2 3 - 4 5 6');
        Test.stopTest();

        Assert.isTrue(resp.verified, 'a spoken code arrives with spaces or dashes');
    }

    @IsTest
    static void wrongCodeDoesNotVerifyAndCountsTheAttempt() {
        OCC_Verification__c v = row('123456', System.now().addMinutes(10), 0);

        Test.startTest();
        OCC_VerifyCode.Response resp = verify(EMAIL, '999999');
        Test.stopTest();

        Assert.isFalse(resp.verified);
        Assert.areEqual('', resp.verifiedEmail, 'a failed check must not return an email to lock to');
        OCC_Verification__c after = [SELECT Attempts__c, Verified__c FROM OCC_Verification__c WHERE Id = :v.Id];
        Assert.areEqual(1, after.Attempts__c);
        Assert.isFalse(after.Verified__c);
    }

    @IsTest
    static void expiredCodeDoesNotVerify() {
        row('123456', System.now().addMinutes(-1), 0);

        Test.startTest();
        OCC_VerifyCode.Response resp = verify(EMAIL, '123456');
        Test.stopTest();

        Assert.isFalse(resp.verified, 'the right code after expiry is still a no');
        Assert.isTrue(resp.message.containsIgnoreCase('expired'));
    }

    @IsTest
    static void tooManyAttemptsLocksTheCodeOut() {
        row('123456', System.now().addMinutes(10), OCC_VerifyCode.MAX_ATTEMPTS);

        Test.startTest();
        OCC_VerifyCode.Response resp = verify(EMAIL, '123456');
        Test.stopTest();

        Assert.isFalse(resp.verified, 'the right code must not rescue an exhausted attempt count');
        Assert.isTrue(resp.message.containsIgnoreCase('too many'));
    }

    @IsTest
    static void codeFromAnotherAddressDoesNotVerify() {
        row('123456', System.now().addMinutes(10), 0);

        Test.startTest();
        OCC_VerifyCode.Response resp = verify('john.smith@example.com', '123456');
        Test.stopTest();

        Assert.isFalse(resp.verified, 'a code is bound to the address it was issued for');
    }

    @IsTest
    static void missingInputAsksForTheCode() {
        Test.startTest();
        OCC_VerifyCode.Response resp = verify(EMAIL, '');
        Test.stopTest();

        Assert.isFalse(resp.verified);
        Assert.isTrue(resp.message.contains('six-digit'));
    }
}
