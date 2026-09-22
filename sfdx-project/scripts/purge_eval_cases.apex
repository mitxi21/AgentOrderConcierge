// Deletes the Cases created by the AGENT USER during eval, Testing Center and Studio runs.
// Runs of the suites create ~5 Cases each, and they accumulate; the demo may show the case list.
//
//   sf apex run --file scripts/purge_eval_cases.apex -o devorg
//
// Kept on purpose (everything the admin or the sample-data load created):
//   00001000-00001025  sample data
//   00001026, 00001027 jane.doe demo cases  (1026 is the one happy_case_status looks up)
//   00001028           john.smith, 00001029 maria.garcia (closed), 00001030 jane.doe
// After the purge: jane.doe keeps 3 open cases (case_list_open_some still passes),
// maria.garcia stays at 0 open (case_list_open_none_offers_to_open still passes),
// alex.chen goes to 0 open, which is the clean state case_open_new_support_case starts from.
//
// The agent user is identified by PROFILE, not by Id, so no redacted identifier lands in the repo.

List<Case> junk = [
    SELECT Id, CaseNumber
    FROM Case
    WHERE Origin = 'Agentforce Agent'
      AND CreatedBy.Profile.Name = 'Einstein Agent User'
];
System.debug(LoggingLevel.ERROR, 'TO DELETE: ' + junk.size());

Integer deleted = 0;
List<Case> chunk = new List<Case>();
for (Case c : junk) {
    chunk.add(c);
    if (chunk.size() == 200) {
        delete chunk;
        deleted += chunk.size();
        chunk.clear();
    }
}
if (!chunk.isEmpty()) {
    delete chunk;
    deleted += chunk.size();
}
System.debug(LoggingLevel.ERROR, 'DELETED: ' + deleted);

System.debug(LoggingLevel.ERROR, 'REMAINING agent-created: ' + [
    SELECT COUNT() FROM Case
    WHERE Origin = 'Agentforce Agent' AND CreatedBy.Profile.Name = 'Einstein Agent User'
]);
System.debug(LoggingLevel.ERROR, 'jane.doe open: ' + [
    SELECT COUNT() FROM Case WHERE Contact.Email = 'jane.doe@example.com' AND IsClosed = false
]);
System.debug(LoggingLevel.ERROR, 'maria.garcia open (must be 0): ' + [
    SELECT COUNT() FROM Case WHERE Contact.Email = 'maria.garcia@example.com' AND IsClosed = false
]);
System.debug(LoggingLevel.ERROR, 'total cases left: ' + [SELECT COUNT() FROM Case]);
