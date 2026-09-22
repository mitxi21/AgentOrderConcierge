// Renames Cases the agent created before the production-like naming existed (2026-09-22):
// "Agent escalation: financial_request" -> "Refund request" + Type/Reason/Origin. Support cases
// the agent opened keep their subject (the caller's own words) and just get Origin/Reason.
//
// Naming comes from OCC_CreateEscalationCase.named(), so this script and the live action can
// never drift apart. Idempotent: re-running changes nothing once every Case is converted.
//
// Run as an admin (needs edit on Case.Type/Reason/Origin - both permission sets grant them):
//   sf apex run --file scripts/rename_agent_cases.apex --target-org devorg

String AGENT_USERNAME = '__AGENT_USERNAME__';
String OLD_PREFIX = 'Agent escalation:';

Id agentUserId = null;
List<User> agentUsers = [SELECT Id FROM User WHERE Username = :AGENT_USERNAME LIMIT 1];
if (!agentUsers.isEmpty()) {
    agentUserId = agentUsers[0].Id;
}

List<Case> toUpdate = new List<Case>();
Integer escalations = 0;
Integer supportCases = 0;

// 1. Old-style escalations, whoever created them (eval runs, smoke tests, the agent itself).
for (Case c : [SELECT Id, Subject FROM Case WHERE Subject LIKE 'Agent escalation:%']) {
    String reasonCode = c.Subject.substring(OLD_PREFIX.length()).trim();
    Case named = OCC_CreateEscalationCase.named(reasonCode);
    toUpdate.add(new Case(
        Id = c.Id,
        Subject = named.Subject,
        Type = named.Type,
        Reason = named.Reason,
        Origin = named.Origin
    ));
    escalations++;
}

// 2. Everything else the agent user created (the support cases): stamp the channel only. Their
//    subject is already the caller's wording, and this action never sets a Type.
if (agentUserId != null) {
    for (Case c : [
        SELECT Id FROM Case
        WHERE CreatedById = :agentUserId
          AND Origin = null
          AND (NOT Subject LIKE 'Agent escalation:%')
    ]) {
        toUpdate.add(new Case(Id = c.Id, Origin = OCC_CreateEscalationCase.AGENT_ORIGIN, Reason = 'Other'));
        supportCases++;
    }
}

if (toUpdate.isEmpty()) {
    System.debug(LoggingLevel.ERROR, 'Nothing to rename - every agent Case already uses the new naming.');
} else {
    update toUpdate;
    System.debug(LoggingLevel.ERROR, 'Renamed ' + escalations + ' escalation Case(s) and stamped '
        + supportCases + ' support Case(s). Total updated: ' + toUpdate.size() + '.');
}
