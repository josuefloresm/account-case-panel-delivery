/**
 * Case counters for one Account, returned by AccountCasePanelController.getCaseSummary.
 *
 * Top-level class on purpose: inner classes are not supported as the return type
 * of an Apex method called from a Lightning web component.
 */
public with sharing class AccountCaseSummary {
    @TestVisible
    private static final String HIGH_PRIORITY = 'High';

    @AuraEnabled
    public Integer openCount = 0;
    @AuraEnabled
    public Integer closedCount = 0;
    @AuraEnabled
    public Integer openHighPriorityCount = 0;

    public void add(Boolean isClosed, String priority, Integer total) {
        if (isClosed) {
            closedCount += total;
            return;
        }
        openCount += total;
        if (priority == HIGH_PRIORITY) {
            openHighPriorityCount += total;
        }
    }
}
