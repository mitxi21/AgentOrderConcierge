// Assigns the least-privilege Order_Case_Concierge_Agent permission set to the
// agent's running user. Run AFTER Agentforce Studio has created (or you've picked)
// that user - this script only handles the permission set assignment, not user creation.
//
// Edit AGENT_USERNAME below to match the exact Username of the agent's running user
// (Setup > Users, or wherever Agentforce Studio shows you the user it created/selected).
//
// Run with: sf apex run --file assign_agent_permset.apex --target-org devorg
// (Or paste into Developer Console > Debug > Open Execute Anonymous Window.)

String AGENT_USERNAME = '__AGENT_USERNAME__';

User agentUser = [SELECT Id, Username FROM User WHERE Username = :AGENT_USERNAME LIMIT 1];

PermissionSet agentPermSet = [
    SELECT Id, Name
    FROM PermissionSet
    WHERE Name = 'Order_Case_Concierge_Agent'
    LIMIT 1
];

List<PermissionSetAssignment> existing = [
    SELECT Id
    FROM PermissionSetAssignment
    WHERE AssigneeId = :agentUser.Id
    AND PermissionSetId = :agentPermSet.Id
];

if (existing.isEmpty()) {
    insert new PermissionSetAssignment(
        AssigneeId = agentUser.Id,
        PermissionSetId = agentPermSet.Id
    );
    System.debug('Assigned Order_Case_Concierge_Agent to ' + agentUser.Username);
} else {
    System.debug('Already assigned - nothing to do.');
}
