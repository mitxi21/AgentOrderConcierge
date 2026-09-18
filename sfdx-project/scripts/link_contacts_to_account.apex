// Links each sample Contact to its own dedicated Account, matching by
// "FirstName LastName" = Account.Name.
//
// A Contact with no AccountId is ALWAYS private in Salesforce, regardless of
// org-wide sharing defaults - that's why setting Contact's OWD to Public Read
// Only didn't fix agent visibility, and why this linkage is what actually made
// the agent able to see Contact records. See CLAUDE.md constraint 2.
//
// PREREQUISITE: import sample-data/accounts_sample.csv (Insert into Account)
// first - this script only matches against Accounts that already exist, it does
// not create them. Re-run after any Contact reload.
//
// Safe to re-run - idempotent (only updates Contacts whose AccountId doesn't
// already point at the correct Account).
//
// Run with: sf apex run --file scripts/link_contacts_to_account.apex --target-org devorg

Map<String, Id> accountIdByName = new Map<String, Id>();
for (Account acct : [SELECT Id, Name FROM Account]) {
    accountIdByName.put(acct.Name, acct.Id);
}

List<Contact> contacts = [SELECT Id, FirstName, LastName, AccountId FROM Contact];
List<Contact> toUpdate = new List<Contact>();
List<String> unmatched = new List<String>();

for (Contact c : contacts) {
    String fullName = (c.FirstName == null ? '' : c.FirstName + ' ') + c.LastName;
    Id acctId = accountIdByName.get(fullName);

    if (acctId == null) {
        unmatched.add(fullName + ' (' + c.Id + ')');
        continue;
    }
    if (c.AccountId != acctId) {
        c.AccountId = acctId;
        toUpdate.add(c);
    }
}

if (!toUpdate.isEmpty()) {
    update toUpdate;
}

System.debug('Linked ' + toUpdate.size() + ' contact(s) to their matching account.');
if (!unmatched.isEmpty()) {
    System.debug('No matching account found for: ' + String.join(unmatched, ', '));
    System.debug('If these are expected, import sample-data/accounts_sample.csv first.');
}
