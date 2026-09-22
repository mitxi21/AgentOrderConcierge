// Deletes the WAV recordings that an Agentforce Studio test suite stores when its
// "Select Conversation Output" is set to Text and voice: one file per conversation, ~10-13 MB.
//
//   sf apex run --file scripts/purge_voice_recordings.apex -o devorg
//
// A Developer Edition org has only 20 MB of FILE storage, so a single 20-conversation voice run
// fills it ("Your organization is using all its file storage") and blocks every later upload,
// including a new test-case CSV. Deleted files keep counting until the recycle bin is emptied,
// which this script does.
//
// Only 'voice_conversation_%' files are touched. The other files in this org are needed:
// the Phase 10 order-workflow diagram PNG (OCC_ExplainOrderWorkflow reads it) and the Phase 13b
// packaging-damage guide PDF.

List<ContentDocument> recordings = [
    SELECT Id, Title, ContentSize FROM ContentDocument WHERE Title LIKE 'voice_conversation_%'
];
Decimal mb = 0;
for (ContentDocument d : recordings) {
    mb += d.ContentSize;
}
System.debug(LoggingLevel.ERROR, 'TO DELETE: ' + recordings.size() + ' files, '
    + (mb / 1024 / 1024).setScale(1) + ' MB');

delete recordings;
Database.emptyRecycleBin(recordings);

System.debug(LoggingLevel.ERROR, 'REMAINING voice files: '
    + [SELECT COUNT() FROM ContentDocument WHERE Title LIKE 'voice_conversation_%']);
for (ContentDocument d : [SELECT Title, FileExtension, ContentSize FROM ContentDocument]) {
    System.debug(LoggingLevel.ERROR, 'KEPT: ' + d.Title + '.' + d.FileExtension + ' ' + d.ContentSize);
}
