@IsTest
private class SM_AutomationLogHelperTest {

    @IsTest
    static void buildsNoteWithNoExistingValue() {
        String note = SM_AutomationLogHelper.appendNote(null, 'SM_TestProcess', 'Did something');
        System.assert(note.startsWith('AUTO: SM_TestProcess - Did something - '), 'Note should start with the standard AUTO prefix.');
    }

    @IsTest
    static void preservesExistingValueAfterSeparator() {
        String note = SM_AutomationLogHelper.appendNote('PREVIOUS_TEXT', 'SM_TestProcess', 'Did something');
        System.assert(note.contains('PREVIOUS_TEXT'), 'The pre-existing value should be preserved.');
        System.assert(note.indexOf('AUTO:') < note.indexOf('PREVIOUS_TEXT'), 'The new note should come before the preserved value.');
    }

    @IsTest
    static void truncatesToMaxLength() {
        String longExisting = ''.rightPad(300, 'X');
        String note = SM_AutomationLogHelper.appendNote(longExisting, 'SM_TestProcess', 'Did something');
        System.assertEquals(200, note.length(), 'The combined note should never exceed the shortest field length across its usages.');
    }
}
