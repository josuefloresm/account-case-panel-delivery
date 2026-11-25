// Creates the demo data: one Account with a Case for every Status x Priority
// combination (read from the org's picklists, so it adapts to custom values)
// and one Account with no Cases. Safe to run more than once.
// Run: sf apex run --file scripts/apex/sample-data.apex
final String WITH_CASES = 'Acme Support Demo (with Cases)';
final String WITHOUT_CASES = 'Globex Demo (no Cases)';

delete [SELECT Id FROM Case WHERE Account.Name IN :new List<String>{ WITH_CASES, WITHOUT_CASES }];
delete [SELECT Id FROM Account WHERE Name IN :new List<String>{ WITH_CASES, WITHOUT_CASES }];

Account withCases = new Account(Name = WITH_CASES);
Account withoutCases = new Account(Name = WITHOUT_CASES);
insert new List<Account>{ withCases, withoutCases };

List<String> statuses = new List<String>();
for (Schema.PicklistEntry entry : Case.Status.getDescribe().getPicklistValues()) {
    if (entry.isActive()) {
        statuses.add(entry.getValue());
    }
}
List<String> priorities = new List<String>();
for (Schema.PicklistEntry entry : Case.Priority.getDescribe().getPicklistValues()) {
    if (entry.isActive()) {
        priorities.add(entry.getValue());
    }
}

List<Case> cases = new List<Case>();
for (String status : statuses) {
    for (String priority : priorities) {
        cases.add(
            new Case(
                AccountId = withCases.Id,
                Subject = priority + ' priority issue (' + status + ')',
                Status = status,
                Priority = priority,
                Origin = 'Phone'
            )
        );
    }
}
insert cases;
System.debug(LoggingLevel.INFO, 'Created ' + cases.size() + ' Cases on ' + WITH_CASES);
