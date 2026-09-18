// Standalone smoke test for all 5 Order & Case Concierge actions, run BEFORE the
// agent exists (per BUILD_RUNBOOK Phase 3: an action that works standalone but
// fails in the agent is a wiring problem; an action never tested is a guessing game).
//
// Run as your admin user with:
//   sf apex run --file scripts/test_actions.apex --target-org devorg
//
// Uses the real sample data already loaded (Jane Doe / ORD-1042, John Smith / ORD-2077,
// Jane's case stored as 00001026). Running as admin exercises the business logic only -
// it does NOT prove FLS/sharing enforcement, since the admin profile bypasses that.
// To prove the least-privilege guardrail itself, re-run the individual snippets below
// (or the actions from the agent) while logged in as the dedicated agent user.

System.debug('=== 1. Get Order Status ===');
OCC_GetOrderStatus.Request s1 = new OCC_GetOrderStatus.Request();
s1.email = 'jane.doe@example.com';
s1.orderNumber = 'ORD-1042';
System.debug(OCC_GetOrderStatus.run(new List<OCC_GetOrderStatus.Request>{ s1 }));

System.debug('=== 2. Check Return Eligibility ===');
OCC_CheckReturnEligibility.Request s2 = new OCC_CheckReturnEligibility.Request();
s2.email = 'john.smith@example.com';
s2.orderNumber = 'ORD-2077';
System.debug(OCC_CheckReturnEligibility.run(new List<OCC_CheckReturnEligibility.Request>{ s2 }));

System.debug('=== 3. Get Case Status (spoken number, no leading zeros) ===');
OCC_GetCaseStatus.Request s3 = new OCC_GetCaseStatus.Request();
s3.email = 'jane.doe@example.com';
s3.caseNumber = '1026';
System.debug(OCC_GetCaseStatus.run(new List<OCC_GetCaseStatus.Request>{ s3 }));

System.debug('=== 4. Update Case (adds a comment) ===');
OCC_UpdateCase.Request s4 = new OCC_UpdateCase.Request();
s4.email = 'jane.doe@example.com';
s4.caseNumber = '1026';
s4.comment = 'Standalone test comment from test_actions.apex.';
System.debug(OCC_UpdateCase.run(new List<OCC_UpdateCase.Request>{ s4 }));

System.debug('=== 5. Create Escalation Case ===');
OCC_CreateEscalationCase.Request s5 = new OCC_CreateEscalationCase.Request();
s5.email = 'jane.doe@example.com';
s5.summary = 'Standalone test: customer asked for a refund, which this agent cannot process.';
s5.reasonCode = 'financial_request';
System.debug(OCC_CreateEscalationCase.run(new List<OCC_CreateEscalationCase.Request>{ s5 }));
