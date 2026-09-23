@IsTest
private class OCC_SendVerificationCodeTest {

    @TestSetup
    static void setup() {
        Account a = new Account(Name = 'Jane Doe');
        insert a;
        insert new Contact(FirstName = 'Jane', LastName = 'Doe', AccountId = a.Id,
                           Email = 'jane.doe@example.com');
    }

    private static OCC_SendVerificationCode.Response send(String email) {
        OCC_SendVerificationCode.Request r = new OCC_SendVerificationCode.Request();
        r.email = email;
        return OCC_SendVerificationCode.run(new List<OCC_SendVerificationCode.Request>{ r })[0];
    }

    @IsTest
    static void sendsCodeAndStoresOnlyAHash() {
        Test.startTest();
        OCC_SendVerificationCode.Response resp = send('jane.doe@example.com');
        Test.stopTest();

        Assert.isTrue(resp.sent, 'a code should be sent for a known contact');
        Assert.areEqual('jane.doe@example.com', resp.claimedEmail);

        List<OCC_Verification__c> rows = [
            SELECT Code_Hash__c, Expires_At__c, Attempts__c, Verified__c, Verified_Email__c, Contact__c
            FROM OCC_Verification__c
        ];
        Assert.areEqual(1, rows.size());
        Assert.areEqual(64, rows[0].Code_Hash__c.length(), 'SHA-256 hex is 64 characters');
        Assert.isFalse(rows[0].Verified__c);
        Assert.areEqual(0, rows[0].Attempts__c);
        Assert.isNotNull(rows[0].Contact__c, 'the row should link to the contact');
        Assert.isTrue(rows[0].Expires_At__c > System.now(), 'the code should not be born expired');
    }

    @IsTest
    static void doesNotRevealWhetherAnAddressExists() {
        Test.startTest();
        OCC_SendVerificationCode.Response known = send('jane.doe@example.com');
        OCC_SendVerificationCode.Response unknown = send('nobody@example.com');
        Test.stopTest();

        Assert.areEqual(known.sent, unknown.sent, 'both must claim a code was sent');
        Assert.areEqual(known.message, unknown.message, 'the message must not differ');
        Assert.areEqual(1, [SELECT COUNT() FROM OCC_Verification__c WHERE Contact__c = null],
            'the unknown address still gets a row, with no contact');
    }

    @IsTest
    static void rejectsAMissingAddress() {
        Test.startTest();
        OCC_SendVerificationCode.Response resp = send('   ');
        Test.stopTest();

        Assert.isFalse(resp.sent);
        Assert.isTrue(resp.message.contains('email address'), 'it should ask for the address');
        Assert.areEqual(0, [SELECT COUNT() FROM OCC_Verification__c]);
    }

    @IsTest
    static void hashIsSaltedWithTheAddress() {
        String a = OCC_SendVerificationCode.hash('123456', 'jane.doe@example.com');
        String b = OCC_SendVerificationCode.hash('123456', 'john.smith@example.com');
        Assert.areNotEqual(a, b, 'the same code must hash differently per address');
        Assert.areEqual(a, OCC_SendVerificationCode.hash('123456', 'JANE.DOE@EXAMPLE.COM'),
            'the address salt should be case-insensitive');
    }

    @IsTest
    static void routesDemoAddressesToThePlusAlias() {
        // Custom metadata IS visible inside tests, so this depends on the org's Keyburn_Setting
        // record. The original version assumed the opposite and only passed while Demo_Inbox__c
        // was empty; it started failing the moment Phase 16 populated it. Assert the shape rather
        // than the address, so the demo inbox never has to be written down here.
        String routed = OCC_SendVerificationCode.routeAddress('jane.doe@example.com');
        String inbox = [
            SELECT Demo_Inbox__c FROM Keyburn_Setting__mdt WHERE DeveloperName = 'Default' LIMIT 1
        ].Demo_Inbox__c;

        if (String.isBlank(inbox)) {
            Assert.areEqual('jane.doe@example.com', routed, 'No demo inbox: leave the address alone');
        } else {
            Assert.isTrue(routed.contains('+jane.doe@'), 'Expected a plus alias, got: ' + routed);
            Assert.areNotEqual('jane.doe@example.com', routed);
        }

        // A real address is never rerouted, whatever the setting says.
        Assert.areEqual('someone@keyburn.test',
            OCC_SendVerificationCode.routeAddress('someone@keyburn.test'));
    }
}
