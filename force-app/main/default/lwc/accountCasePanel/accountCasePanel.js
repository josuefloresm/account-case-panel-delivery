import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';

import getCases from '@salesforce/apex/AccountCasePanelController.getCases';
import getCaseSummary from '@salesforce/apex/AccountCasePanelController.getCaseSummary';

import CASE_OBJECT from '@salesforce/schema/Case';
import CASE_NUMBER_FIELD from '@salesforce/schema/Case.CaseNumber';
import SUBJECT_FIELD from '@salesforce/schema/Case.Subject';
import STATUS_FIELD from '@salesforce/schema/Case.Status';
import PRIORITY_FIELD from '@salesforce/schema/Case.Priority';
import CREATED_DATE_FIELD from '@salesforce/schema/Case.CreatedDate';

import TITLE from '@salesforce/label/c.ACP_Title';
import OPEN from '@salesforce/label/c.ACP_Open';
import CLOSED from '@salesforce/label/c.ACP_Closed';
import OPEN_HIGH_PRIORITY from '@salesforce/label/c.ACP_OpenHighPriority';
import FILTER_STATUS from '@salesforce/label/c.ACP_FilterStatus';
import FILTER_PRIORITY from '@salesforce/label/c.ACP_FilterPriority';
import ALL_OPTION from '@salesforce/label/c.ACP_AllOption';
import LOADING from '@salesforce/label/c.ACP_Loading';
import NO_CASES from '@salesforce/label/c.ACP_NoCases';
import NO_MATCHES from '@salesforce/label/c.ACP_NoMatches';
import LOAD_ERROR from '@salesforce/label/c.ACP_LoadError';
import LIST_TRUNCATED from '@salesforce/label/c.ACP_ListTruncated';

const ALL = '';
const TILE_VALUE_CLASS = 'slds-text-heading_large';

// Fields whose schema labels become column headers. getObjectInfo omits fields the
// user cannot read (field-level security), so each one must be checked before use.
const COLUMN_FIELDS = [
    CASE_NUMBER_FIELD,
    SUBJECT_FIELD,
    STATUS_FIELD,
    PRIORITY_FIELD,
    CREATED_DATE_FIELD
];

const formatLabel = (label, ...values) =>
    values.reduce((text, value, index) => text.replace(`{${index}}`, value), label);

export default class AccountCasePanel extends NavigationMixin(LightningElement) {
    @api recordId;

    labels = {
        TITLE,
        FILTER_STATUS,
        FILTER_PRIORITY,
        LOADING,
        LOAD_ERROR
    };

    casesResult;
    casesWithUrls; // Cases plus their record URL; undefined until the first load completes
    casesRequestId = 0;
    columns = [];
    objectInfoError;
    recordTypeId;
    statusFilter = ALL;
    priorityFilter = ALL;

    @wire(getCases, { accountId: '$recordId' })
    wiredCases(result) {
        this.casesResult = result;
        if (result.data) {
            this.attachRecordUrls(result.data);
        }
    }

    @wire(getCaseSummary, { accountId: '$recordId' })
    summary;

    @wire(getObjectInfo, { objectApiName: CASE_OBJECT })
    wiredObjectInfo({ data, error }) {
        this.objectInfoError = error;
        this.columns = [];
        if (!data) {
            return;
        }
        this.recordTypeId = data.defaultRecordTypeId;
        const missing = COLUMN_FIELDS.map((field) => field.fieldApiName).filter(
            (name) => !data.fields?.[name]
        );
        if (missing.length) {
            // Shown as the controlled load error; the field names stay in the console.
            console.error(`Case fields missing from object info: ${missing.join(', ')}`);
            this.objectInfoError = new Error('MISSING_CASE_FIELDS');
            return;
        }
        this.columns = this.buildColumns(data.fields);
    }

    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: STATUS_FIELD })
    statusValues;

    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: PRIORITY_FIELD })
    priorityValues;

    // The spinner stays until every source the panel renders from has answered.
    get isLoading() {
        const isPending = (wired) => !wired?.data && !wired?.error;
        const columnsPending = !this.columns.length && !this.objectInfoError;
        const casesPending = !this.casesWithUrls && !this.casesResult?.error;
        const pending =
            casesPending ||
            isPending(this.summary) ||
            isPending(this.statusValues) ||
            isPending(this.priorityValues) ||
            columnsPending;
        return pending && !this.hasError;
    }

    // Load errors always surface as one readable label; Apex already logs the technical detail.
    get hasError() {
        return [
            this.casesResult?.error,
            this.summary?.error,
            this.objectInfoError,
            this.statusValues?.error,
            this.priorityValues?.error
        ].some(Boolean);
    }

    get statusOptions() {
        return this.toOptions(this.statusValues);
    }

    get priorityOptions() {
        return this.toOptions(this.priorityValues);
    }

    get cases() {
        return this.casesWithUrls ?? [];
    }

    // Counters cover every Case while the list is capped, so say so when they differ.
    get truncatedMessage() {
        const { openCount, closedCount } = this.summary?.data ?? {};
        const total = openCount + closedCount;
        return total > this.cases.length
            ? formatLabel(LIST_TRUNCATED, this.cases.length, total)
            : '';
    }

    get filteredCases() {
        return this.cases.filter(
            (record) =>
                (this.statusFilter === ALL || record.Status === this.statusFilter) &&
                (this.priorityFilter === ALL || record.Priority === this.priorityFilter)
        );
    }

    get hasRows() {
        return this.filteredCases.length > 0;
    }

    get emptyMessage() {
        return this.cases.length ? NO_MATCHES : NO_CASES;
    }

    get showList() {
        return Boolean(this.casesWithUrls) && this.columns.length > 0;
    }

    get summaryTiles() {
        const { openCount, closedCount, openHighPriorityCount } = this.summary.data;
        return [
            { key: 'open', label: OPEN, value: openCount, valueClass: TILE_VALUE_CLASS },
            { key: 'closed', label: CLOSED, value: closedCount, valueClass: TILE_VALUE_CLASS },
            {
                key: 'openHighPriority',
                label: OPEN_HIGH_PRIORITY,
                value: openHighPriorityCount,
                valueClass:
                    openHighPriorityCount > 0
                        ? `${TILE_VALUE_CLASS} slds-text-color_error`
                        : TILE_VALUE_CLASS
            }
        ];
    }

    handleStatusChange(event) {
        this.statusFilter = event.detail.value;
    }

    handlePriorityChange(event) {
        this.priorityFilter = event.detail.value;
    }

    // Standard record URLs keep the Case Number a real link (new tab, copy address).
    // A row whose URL cannot be generated degrades to plain text instead of failing the list.
    // The request id drops the result of a load that a newer one has already replaced.
    async attachRecordUrls(records) {
        const requestId = ++this.casesRequestId;
        const urls = await Promise.all(
            records.map((record) =>
                this[NavigationMixin.GenerateUrl]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: record.Id,
                        objectApiName: CASE_OBJECT.objectApiName,
                        actionName: 'view'
                    }
                }).catch(() => null)
            )
        );
        if (requestId === this.casesRequestId) {
            this.casesWithUrls = records.map((record, index) => ({
                ...record,
                recordUrl: urls[index]
            }));
        }
    }

    buildColumns(fields) {
        const labelOf = (field) => fields[field.fieldApiName].label;
        return [
            {
                label: labelOf(CASE_NUMBER_FIELD),
                fieldName: 'recordUrl',
                type: 'url',
                typeAttributes: {
                    label: { fieldName: CASE_NUMBER_FIELD.fieldApiName },
                    target: '_self'
                }
            },
            {
                label: labelOf(SUBJECT_FIELD),
                fieldName: SUBJECT_FIELD.fieldApiName,
                wrapText: true
            },
            {
                label: labelOf(STATUS_FIELD),
                fieldName: STATUS_FIELD.fieldApiName
            },
            {
                label: labelOf(PRIORITY_FIELD),
                fieldName: PRIORITY_FIELD.fieldApiName
            },
            {
                label: labelOf(CREATED_DATE_FIELD),
                fieldName: CREATED_DATE_FIELD.fieldApiName,
                type: 'date',
                typeAttributes: {
                    year: 'numeric',
                    month: 'short',
                    day: '2-digit',
                    hour: '2-digit',
                    minute: '2-digit'
                }
            }
        ];
    }

    toOptions(picklist) {
        const values = picklist?.data?.values ?? [];
        return [
            { label: ALL_OPTION, value: ALL },
            ...values.map(({ label, value }) => ({ label, value }))
        ];
    }
}
