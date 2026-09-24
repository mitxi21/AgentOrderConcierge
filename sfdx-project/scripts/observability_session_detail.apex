// Phase 17 - reconstruct one traced session turn by turn from the STDM, the way the Sessions &
// Intents drill-down does. Pick a session id from observability_readout.apex
// ('escalated_session_ids'), paste it below, and run:
//   sf apex run --file scripts/observability_session_detail.apex --target-org devorg
// Read the output with (2026-09-24): the CLI HTML-escapes the pipe in debug output, so a plain
// Select-String "DETAIL\|" matches only this file's own source echo and no data at all.
//   sf apex run --file scripts/observability_session_detail.apex --target-org devorg |
//     Select-String "USER_DEBUG.*DETAIL" |
//     ForEach-Object { ($_ -replace '.*DEBUG\|DETAIL&#124;','') -replace '&#124;',' | ' }

final String DATA_SPACE = 'default';
final String SESSION_ID = '01a0ca6f-a0d0-743d-b8e4-1537a25cce15';

List<List<String>> queries = new List<List<String>>();

queries.add(new List<String>{ 'session',
    // DISTINCT: a session has one participant row per turn, so the join fans out without it.
    'SELECT DISTINCT s.ssot__AiAgentChannelType__c AS channel, s.ssot__StartTimestamp__c AS started,' +
    ' s.ssot__EndTimestamp__c AS ended, p.ssot__AiAgentVersionApiName__c AS agent_version' +
    ' FROM "ssot__AiAgentSession__dlm" s' +
    ' JOIN "ssot__AiAgentSessionParticipant__dlm" p ON p.ssot__AiAgentSessionId__c = s.ssot__Id__c' +
    ' WHERE s.ssot__Id__c = \'' + SESSION_ID + '\'' +
    '   AND p.ssot__AiAgentSessionParticipantRole__c <> \'USER\'' });

queries.add(new List<String>{ 'messages',
    'SELECT ssot__MessageSentTimestamp__c AS sent,' +
    ' ssot__AiAgentInteractionMessageType__c AS direction, ssot__ContentText__c AS text' +
    ' FROM "ssot__AiAgentInteractionMessage__dlm"' +
    ' WHERE ssot__AiAgentSessionId__c = \'' + SESSION_ID + '\'' +
    ' ORDER BY 1 LIMIT 60' });

queries.add(new List<String>{ 'turns',
    'SELECT ssot__StartTimestamp__c AS started,' +
    ' REGEXP_REPLACE(ssot__TopicApiName__c, \'_16j[A-Za-z0-9]+$\', \'\') AS subagent,' +
    ' DATE_DIFF(\'millisecond\', ssot__StartTimestamp__c, ssot__EndTimestamp__c) AS duration_ms' +
    ' FROM "ssot__AiAgentInteraction__dlm"' +
    ' WHERE ssot__AiAgentSessionId__c = \'' + SESSION_ID + '\'' +
    ' ORDER BY 1 LIMIT 40' });

queries.add(new List<String>{ 'steps',
    'SELECT st.ssot__StartTimestamp__c AS started, st.ssot__AiAgentInteractionStepType__c AS step_type,' +
    ' st.ssot__Name__c AS name, st.ssot__ErrorMessageText__c AS error' +
    ' FROM "ssot__AiAgentInteractionStep__dlm" st' +
    ' JOIN "ssot__AiAgentInteraction__dlm" i ON i.ssot__Id__c = st.ssot__AiAgentInteractionId__c' +
    ' WHERE i.ssot__AiAgentSessionId__c = \'' + SESSION_ID + '\'' +
    ' ORDER BY 1 LIMIT 120' });

// What the escalation action was actually given and what it returned.
queries.add(new List<String>{ 'action_io',
    'SELECT st.ssot__Name__c AS name, st.ssot__InputValueText__c AS input,' +
    ' st.ssot__OutputValueText__c AS output' +
    ' FROM "ssot__AiAgentInteractionStep__dlm" st' +
    ' JOIN "ssot__AiAgentInteraction__dlm" i ON i.ssot__Id__c = st.ssot__AiAgentInteractionId__c' +
    ' WHERE i.ssot__AiAgentSessionId__c = \'' + SESSION_ID + '\'' +
    '   AND st.ssot__AiAgentInteractionStepType__c = \'ACTION_STEP\' LIMIT 10' });

queries.add(new List<String>{ 'moment',
    'SELECT m.ssot__RequestSummaryText__c AS intent, m.ssot__ResponseSummaryText__c AS response,' +
    ' d.ssot__Name__c AS tag_definition, t.ssot__Value__c AS value,' +
    ' a.ssot__AssociationReasonText__c AS reason' +
    ' FROM "ssot__AiAgentMoment__dlm" m' +
    ' LEFT JOIN "ssot__AiAgentTagAssociation__dlm" a ON a.ssot__AiAgentMomentId__c = m.ssot__Id__c' +
    ' LEFT JOIN "ssot__AiAgentTag__dlm" t ON t.ssot__Id__c = a.ssot__AiAgentTagId__c' +
    ' LEFT JOIN "ssot__AiAgentTagDefinition__dlm" d ON d.ssot__Id__c = t.ssot__AiAgentTagDefinitionId__c' +
    ' WHERE m.ssot__AiAgentSessionId__c = \'' + SESSION_ID + '\' LIMIT 20' });

for (List<String> q : queries) {
    String name = q[0];
    try {
        ConnectApi.CdpQueryInput qi = new ConnectApi.CdpQueryInput();
        qi.sql = q[1];
        ConnectApi.CdpQueryOutputV2 res = ConnectApi.CdpQuery.queryAnsiSqlV2(qi, DATA_SPACE);

        List<String> cols = new List<String>();
        if (res.metadata != null) {
            for (Integer i = 0; i < res.metadata.size(); i++) { cols.add('col' + i); }
            for (String c : res.metadata.keySet()) {
                Integer pos = res.metadata.get(c).placeInOrder;
                if (pos != null && pos < cols.size()) { cols.set(pos, c); }
            }
        }
        System.debug('DETAIL|' + name + '|COLS|' + String.join(cols, ' | '));

        if (res.data == null || res.data.isEmpty()) {
            System.debug('DETAIL|' + name + '|EMPTY');
        } else {
            for (ConnectApi.CdpQueryV2Row row : res.data) {
                List<String> cells = new List<String>();
                for (Object v : row.rowData) {
                    String s = (v == null) ? '' : String.valueOf(v);
                    if (s.length() > 300) { s = s.substring(0, 300) + '...'; }
                    cells.add(s.replaceAll('\\s+', ' '));
                }
                System.debug('DETAIL|' + name + '|ROW|' + String.join(cells, ' | '));
            }
        }
    } catch (Exception e) {
        System.debug('DETAIL|' + name + '|FAIL|' + e.getMessage());
    }
}
