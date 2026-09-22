// Phase 17 - observability readout over the Session Tracing Data Model (STDM) in Data 360.
//
// Why this exists: the Agent Analytics dashboards and Sessions & Intents are the demo surfaces,
// but they can lag or render empty. This script reads the same trace data straight out of Data
// Cloud, so the numbers can be quoted (and reconciled with the dashboards) without a UI.
//
// Run from sfdx-project/ in PowerShell (sf breaks in Git Bash on the "C:\Program" path bug):
//   sf apex run --file scripts/observability_readout.apex --target-org devorg
// Read the output with: Select-String "READOUT\|"
//
// The CLI access token has no Data Cloud scope, so /ssot/query-sql returns 401. ConnectApi.CdpQuery
// from anonymous Apex is the working route (Phase 12). No Apex class is deployed for this.

final String DATA_SPACE = 'default';
final String AGENT      = 'Keyburn_Customer_Service';

List<List<String>> queries = new List<List<String>>();

queries.add(new List<String>{ 'window',
    'SELECT COUNT(DISTINCT ssot__AiAgentSessionId__c) AS sessions,' +
    ' MIN(ssot__StartTimestamp__c) AS first_session,' +
    ' MAX(ssot__StartTimestamp__c) AS last_session' +
    ' FROM "ssot__AiAgentSessionParticipant__dlm"' +
    ' WHERE ssot__AiAgentApiName__c = \'' + AGENT + '\'' });

queries.add(new List<String>{ 'sessions_by_version',
    'SELECT ssot__AiAgentVersionApiName__c AS agent_version,' +
    ' COUNT(DISTINCT ssot__AiAgentSessionId__c) AS sessions' +
    ' FROM "ssot__AiAgentSessionParticipant__dlm"' +
    ' WHERE ssot__AiAgentApiName__c = \'' + AGENT + '\'' +
    ' GROUP BY 1 ORDER BY 2 DESC' });

queries.add(new List<String>{ 'sessions_by_channel',
    'SELECT s.ssot__AiAgentChannelType__c AS channel,' +
    ' s.ssot__AiAgentSessionEndType__c AS end_type,' +
    ' COUNT(DISTINCT s.ssot__Id__c) AS sessions' +
    ' FROM "ssot__AiAgentSession__dlm" s' +
    ' JOIN "ssot__AiAgentSessionParticipant__dlm" p ON p.ssot__AiAgentSessionId__c = s.ssot__Id__c' +
    ' WHERE p.ssot__AiAgentApiName__c = \'' + AGENT + '\'' +
    ' GROUP BY 1, 2 ORDER BY 3 DESC' });

// Subagent names carry the planner id of the version that handled the turn
// (order_status_16jak000003GChp), so they are collapsed back to the Agent Script name.
queries.add(new List<String>{ 'turns_by_subagent',
    'SELECT REGEXP_REPLACE(ssot__TopicApiName__c, \'_16j[A-Za-z0-9]+$\', \'\') AS subagent,' +
    ' COUNT(1) AS turns, COUNT(DISTINCT ssot__AiAgentSessionId__c) AS sessions' +
    ' FROM "ssot__AiAgentInteraction__dlm"' +
    ' GROUP BY 1 ORDER BY 2 DESC' });

queries.add(new List<String>{ 'step_types',
    'SELECT ssot__AiAgentInteractionStepType__c AS step_type, COUNT(1) AS steps' +
    ' FROM "ssot__AiAgentInteractionStep__dlm"' +
    ' GROUP BY 1 ORDER BY 2 DESC' });

// 'NOT_SET' is the STDM sentinel for an empty value, so an error count must exclude it as well as null.
queries.add(new List<String>{ 'actions',
    'SELECT ssot__Name__c AS action_name, COUNT(1) AS calls,' +
    ' SUM(CASE WHEN ssot__ErrorMessageText__c IS NOT NULL' +
    '          AND ssot__ErrorMessageText__c <> \'NOT_SET\' THEN 1 ELSE 0 END) AS errors' +
    ' FROM "ssot__AiAgentInteractionStep__dlm"' +
    ' WHERE ssot__AiAgentInteractionStepType__c = \'ACTION_STEP\'' +
    ' GROUP BY 1 ORDER BY 2 DESC LIMIT 40' });

queries.add(new List<String>{ 'action_errors',
    'SELECT ssot__Name__c AS action_name, ssot__ErrorMessageText__c AS error_text, COUNT(1) AS n' +
    ' FROM "ssot__AiAgentInteractionStep__dlm"' +
    ' WHERE ssot__ErrorMessageText__c IS NOT NULL AND ssot__ErrorMessageText__c <> \'NOT_SET\'' +
    ' GROUP BY 1, 2 ORDER BY 3 DESC LIMIT 15' });

// Containment / escalation: a session counts as escalated when it ran the escalation action.
queries.add(new List<String>{ 'escalation_rate',
    'SELECT COUNT(DISTINCT i.ssot__AiAgentSessionId__c) AS escalated_sessions' +
    ' FROM "ssot__AiAgentInteractionStep__dlm" st' +
    ' JOIN "ssot__AiAgentInteraction__dlm" i ON i.ssot__Id__c = st.ssot__AiAgentInteractionId__c' +
    ' WHERE st.ssot__Name__c LIKE \'%EscalationCase%\'' });

queries.add(new List<String>{ 'turn_latency_ms',
    'SELECT AVG(DATE_DIFF(\'millisecond\', ssot__StartTimestamp__c, ssot__EndTimestamp__c)) AS avg_ms,' +
    ' MAX(DATE_DIFF(\'millisecond\', ssot__StartTimestamp__c, ssot__EndTimestamp__c)) AS max_ms,' +
    ' COUNT(1) AS turns' +
    ' FROM "ssot__AiAgentInteraction__dlm"' +
    ' WHERE ssot__EndTimestamp__c IS NOT NULL' });

queries.add(new List<String>{ 'intents',
    'SELECT ssot__RequestSummaryText__c AS intent, COUNT(1) AS moments' +
    ' FROM "ssot__AiAgentMoment__dlm"' +
    ' WHERE ssot__AiAgentApiName__c = \'' + AGENT + '\'' +
    ' GROUP BY 1 ORDER BY 2 DESC LIMIT 25' });

// One moment carries several tag types (response quality 1-5, a boolean, "Unsure"), so the
// tag definition has to be part of the grouping or the scores come out mixed together.
queries.add(new List<String>{ 'tags_by_definition',
    'SELECT d.ssot__Name__c AS tag_definition, t.ssot__Value__c AS value, COUNT(1) AS moments' +
    ' FROM "ssot__AiAgentTagAssociation__dlm" a' +
    ' JOIN "ssot__AiAgentTag__dlm" t ON t.ssot__Id__c = a.ssot__AiAgentTagId__c' +
    ' JOIN "ssot__AiAgentTagDefinition__dlm" d ON d.ssot__Id__c = t.ssot__AiAgentTagDefinitionId__c' +
    ' GROUP BY 1, 2 ORDER BY 1, 2' });

// Value is text and not every tag type is numeric, so match the two low scores literally.
queries.add(new List<String>{ 'low_quality_moments',
    'SELECT t.ssot__Value__c AS score, m.ssot__AiAgentSessionId__c AS session_id,' +
    ' m.ssot__RequestSummaryText__c AS intent' +
    ' FROM "ssot__AiAgentTagAssociation__dlm" a' +
    ' JOIN "ssot__AiAgentTag__dlm" t ON t.ssot__Id__c = a.ssot__AiAgentTagId__c' +
    ' JOIN "ssot__AiAgentMoment__dlm" m ON m.ssot__Id__c = a.ssot__AiAgentMomentId__c' +
    ' WHERE t.ssot__Value__c IN (\'1\', \'2\') ORDER BY 1 LIMIT 15' });

// An escalated session, newest first - feed one of these ids to observability_session_detail.apex.
queries.add(new List<String>{ 'escalated_session_ids',
    'SELECT i.ssot__AiAgentSessionId__c AS session_id, MAX(st.ssot__StartTimestamp__c) AS ts' +
    ' FROM "ssot__AiAgentInteractionStep__dlm" st' +
    ' JOIN "ssot__AiAgentInteraction__dlm" i ON i.ssot__Id__c = st.ssot__AiAgentInteractionId__c' +
    ' WHERE st.ssot__Name__c LIKE \'%EscalationCase%\'' +
    ' GROUP BY 1 ORDER BY 2 DESC LIMIT 5' });

for (List<String> q : queries) {
    String name = q[0];
    try {
        ConnectApi.CdpQueryInput qi = new ConnectApi.CdpQueryInput();
        qi.sql = q[1];
        ConnectApi.CdpQueryOutputV2 res = ConnectApi.CdpQuery.queryAnsiSqlV2(qi, DATA_SPACE);

        // Column order comes from metadata.placeInOrder, not from keySet() order.
        List<String> cols = new List<String>();
        if (res.metadata != null) {
            for (Integer i = 0; i < res.metadata.size(); i++) { cols.add('col' + i); }
            for (String c : res.metadata.keySet()) {
                Integer pos = res.metadata.get(c).placeInOrder;
                if (pos != null && pos < cols.size()) { cols.set(pos, c); }
            }
        }
        System.debug('READOUT|' + name + '|COLS|' + String.join(cols, ' | '));

        if (res.data == null || res.data.isEmpty()) {
            System.debug('READOUT|' + name + '|EMPTY');
        } else {
            for (ConnectApi.CdpQueryV2Row row : res.data) {
                List<String> cells = new List<String>();
                for (Object v : row.rowData) {
                    String s = (v == null) ? '' : String.valueOf(v);
                    if (s.length() > 160) { s = s.substring(0, 160) + '...'; }
                    cells.add(s.replaceAll('\\s+', ' '));
                }
                System.debug('READOUT|' + name + '|ROW|' + String.join(cells, ' | '));
            }
        }
    } catch (Exception e) {
        System.debug('READOUT|' + name + '|FAIL|' + e.getMessage());
    }
}
