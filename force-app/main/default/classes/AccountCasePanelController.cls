/**
 * Read-only data access for the accountCasePanel LWC.
 *
 * Writes (closing a Case) go through Lightning Data Service in the component,
 * so this class only exposes cacheable queries. Every query runs in user mode:
 * sharing, object permissions and field-level security of the running user apply.
 */
public with sharing class AccountCasePanelController {
    @TestVisible
    private static final Integer MAX_CASES = 50;

    /**
     * Returns the most recent Cases of an Account, newest first.
     * Filtering by Status and Priority happens in the browser over this list.
     */
    @AuraEnabled(cacheable=true)
    public static List<Case> getCases(Id accountId) {
        if (accountId == null) {
            return new List<Case>();
        }
        try {
            return [
                SELECT Id, CaseNumber, Subject, Status, Priority, IsClosed, CreatedDate
                FROM Case
                WHERE AccountId = :accountId
                WITH USER_MODE
                ORDER BY CreatedDate DESC, CaseNumber DESC
                LIMIT :MAX_CASES
            ];
        } catch (Exception e) {
            throw handledException(e);
        }
    }

    /**
     * Returns Open, Closed and Open High-Priority totals for every Case of the
     * Account (not limited to the 50 shown in the list), using one aggregate query.
     */
    @AuraEnabled(cacheable=true)
    public static AccountCaseSummary getCaseSummary(Id accountId) {
        AccountCaseSummary summary = new AccountCaseSummary();
        if (accountId == null) {
            return summary;
        }
        try {
            for (AggregateResult row : [
                SELECT IsClosed, Priority, COUNT(Id) total
                FROM Case
                WHERE AccountId = :accountId
                WITH USER_MODE
                GROUP BY IsClosed, Priority
            ]) {
                summary.add(
                    (Boolean) row.get('IsClosed'),
                    (String) row.get('Priority'),
                    (Integer) row.get('total')
                );
            }
            return summary;
        } catch (Exception e) {
            throw handledException(e);
        }
    }

    /**
     * Logs the technical detail for admins and returns an exception whose message
     * is a readable custom label, so no raw exception reaches the screen.
     */
    private static AuraHandledException handledException(Exception cause) {
        System.debug(LoggingLevel.ERROR, cause.getTypeName() + ': ' + cause.getMessage());
        AuraHandledException handled = new AuraHandledException(Label.ACP_LoadError);
        handled.setMessage(Label.ACP_LoadError);
        return handled;
    }
}
