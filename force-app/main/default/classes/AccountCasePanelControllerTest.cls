@IsTest
private class AccountCasePanelControllerTest {
    private static final String STATUS_NEW = 'New';
    private static final String STATUS_CLOSED = 'Closed';
    private static final String PRIORITY_LOW = 'Low';

    @TestSetup
    static void setup() {
        Account withCases = new Account(Name = 'With Cases');
        Account withoutCases = new Account(Name = 'Without Cases');
        Account other = new Account(Name = 'Other Account');
        insert new List<Account>{ withCases, withoutCases, other };

        insert new List<Case>{
            newCase(withCases.Id, 'Open high 1', STATUS_NEW, AccountCaseSummary.HIGH_PRIORITY),
            newCase(withCases.Id, 'Open high 2', STATUS_NEW, AccountCaseSummary.HIGH_PRIORITY),
            newCase(withCases.Id, 'Open low', STATUS_NEW, PRIORITY_LOW),
            newCase(withCases.Id, 'Closed high', STATUS_CLOSED, AccountCaseSummary.HIGH_PRIORITY),
            newCase(
                other.Id,
                'Belongs to another account',
                STATUS_NEW,
                AccountCaseSummary.HIGH_PRIORITY
            )
        };
    }

    @IsTest
    static void getCasesReturnsOnlyTheAccountCasesNewestFirst() {
        Id accountId = accountId('With Cases');
        List<Case> cases = [SELECT Id FROM Case WHERE AccountId = :accountId ORDER BY Subject];
        Datetime base = Datetime.now().addDays(-10);
        for (Integer i = 0; i < cases.size(); i++) {
            Test.setCreatedDate(cases[i].Id, base.addDays(i));
        }

        Test.startTest();
        List<Case> result = AccountCasePanelController.getCases(accountId);
        Test.stopTest();

        Assert.areEqual(4, result.size(), 'Only the Cases of the requested Account are returned');
        for (Integer i = 1; i < result.size(); i++) {
            Assert.isTrue(
                result[i - 1].CreatedDate >= result[i].CreatedDate,
                'Cases must be sorted by Created Date, newest first'
            );
        }
        Assert.areEqual(
            cases[cases.size() - 1].Id,
            result[0].Id,
            'The most recently created Case comes first'
        );
        Assert.isNotNull(result[0].CaseNumber, 'Case Number is queried for the datatable link');
        Assert.isNotNull(result[0].Status, 'Status is queried for filtering');
        Assert.isNotNull(result[0].Priority, 'Priority is queried for filtering');
    }

    @IsTest
    static void getCasesIsCappedAtFiftyRecords() {
        Id accountId = accountId('Without Cases');
        List<Case> manyCases = new List<Case>();
        for (Integer i = 0; i < AccountCasePanelController.MAX_CASES + 5; i++) {
            manyCases.add(newCase(accountId, 'Bulk ' + i, STATUS_NEW, PRIORITY_LOW));
        }
        insert manyCases;

        Test.startTest();
        List<Case> result = AccountCasePanelController.getCases(accountId);
        Test.stopTest();

        Assert.areEqual(
            AccountCasePanelController.MAX_CASES,
            result.size(),
            'The list is limited to the 50 most recent Cases'
        );
    }

    @IsTest
    static void getCaseSummaryCountsOpenClosedAndOpenHighPriority() {
        Test.startTest();
        AccountCaseSummary summary = AccountCasePanelController.getCaseSummary(
            accountId('With Cases')
        );
        Test.stopTest();

        Assert.areEqual(3, summary.openCount, 'Three Cases are open');
        Assert.areEqual(1, summary.closedCount, 'One Case is closed');
        Assert.areEqual(
            2,
            summary.openHighPriorityCount,
            'A closed High Case is not counted as open high priority'
        );
    }

    @IsTest
    static void getCaseSummaryReflectsAClosedCase() {
        Id accountId = accountId('With Cases');
        Case openHigh = [SELECT Id FROM Case WHERE Subject = 'Open high 1' LIMIT 1];
        update new Case(Id = openHigh.Id, Status = STATUS_CLOSED);

        Test.startTest();
        AccountCaseSummary summary = AccountCasePanelController.getCaseSummary(accountId);
        Test.stopTest();

        Assert.areEqual(2, summary.openCount, 'Closing a Case decreases the open total');
        Assert.areEqual(2, summary.closedCount, 'Closing a Case increases the closed total');
        Assert.areEqual(
            1,
            summary.openHighPriorityCount,
            'Closing a High Case decreases the open high-priority total'
        );
    }

    @IsTest
    static void getCaseSummaryCountsCasesWithoutPriorityAsOpenButNotHighPriority() {
        Id accountId = accountId('Without Cases');
        insert newCase(accountId, 'No priority', STATUS_NEW, null);

        Test.startTest();
        AccountCaseSummary summary = AccountCasePanelController.getCaseSummary(accountId);
        Test.stopTest();

        Assert.areEqual(1, summary.openCount, 'A Case without priority is still open');
        Assert.areEqual(0, summary.closedCount, 'No Case is closed');
        Assert.areEqual(
            0,
            summary.openHighPriorityCount,
            'A Case without priority is not high priority'
        );
    }

    @IsTest
    static void accountWithoutCasesReturnsEmptyListAndZeroCounters() {
        Id accountId = accountId('Without Cases');

        Test.startTest();
        List<Case> cases = AccountCasePanelController.getCases(accountId);
        AccountCaseSummary summary = AccountCasePanelController.getCaseSummary(accountId);
        Test.stopTest();

        Assert.isTrue(cases.isEmpty(), 'An Account without Cases returns an empty list');
        assertZeroCounters(summary);
    }

    @IsTest
    static void nullAccountIdReturnsEmptyResultsWithoutQuerying() {
        Test.startTest();
        List<Case> cases = AccountCasePanelController.getCases(null);
        AccountCaseSummary summary = AccountCasePanelController.getCaseSummary(null);
        Integer queries = Limits.getQueries();
        Test.stopTest();

        Assert.isTrue(cases.isEmpty(), 'A null Account Id returns an empty list');
        assertZeroCounters(summary);
        Assert.areEqual(0, queries, 'No SOQL is spent on a null Account Id');
    }

    @IsTest
    static void userWithoutCaseAccessGetsReadableErrors() {
        Id accountId = accountId('With Cases');
        String casesError;
        String summaryError;

        System.runAs(minimumAccessUser()) {
            Test.startTest();
            try {
                AccountCasePanelController.getCases(accountId);
            } catch (AuraHandledException e) {
                casesError = e.getMessage();
            }
            try {
                AccountCasePanelController.getCaseSummary(accountId);
            } catch (AuraHandledException e) {
                summaryError = e.getMessage();
            }
            Test.stopTest();
        }

        Assert.areEqual(
            Label.ACP_LoadError,
            casesError,
            'getCases shows the readable label, not the raw exception'
        );
        Assert.areEqual(
            Label.ACP_LoadError,
            summaryError,
            'getCaseSummary shows the readable label, not the raw exception'
        );
    }

    private static void assertZeroCounters(AccountCaseSummary summary) {
        Assert.areEqual(0, summary.openCount, 'No open Cases');
        Assert.areEqual(0, summary.closedCount, 'No closed Cases');
        Assert.areEqual(0, summary.openHighPriorityCount, 'No open high-priority Cases');
    }

    private static Case newCase(Id accountId, String subject, String status, String priority) {
        return new Case(
            AccountId = accountId,
            Subject = subject,
            Status = status,
            Priority = priority,
            Origin = 'Web'
        );
    }

    private static Id accountId(String name) {
        return [SELECT Id FROM Account WHERE Name = :name LIMIT 1].Id;
    }

    private static User minimumAccessUser() {
        Profile minimumAccess = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Minimum Access - Salesforce'
            LIMIT 1
        ];
        String uniqueName = 'acp.restricted.' + Crypto.getRandomInteger() + '@example.com';
        User restricted = new User(
            ProfileId = minimumAccess.Id,
            Username = uniqueName,
            Email = uniqueName,
            LastName = 'Restricted',
            Alias = 'acprest',
            TimeZoneSidKey = 'America/Santiago',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert restricted;
        return restricted;
    }
}
