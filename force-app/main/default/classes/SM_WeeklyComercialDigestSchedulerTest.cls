@IsTest
private class SM_WeeklyComercialDigestSchedulerTest {

    @IsTest
    static void schedulerRunsWithoutError() {
        Test.startTest();
            String jobId = System.schedule(
                'SM_WeeklyComercialDigestScheduler_Test', '0 0 8 ? * MON', new SM_WeeklyComercialDigestScheduler()
            );
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'The scheduled job should be created successfully.');
    }
}
