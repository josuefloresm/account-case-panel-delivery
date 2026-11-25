# Account Case Panel

LWC for the Account record page: Case counters, status/priority filters and a "Close Case" action.

**Setup** (Salesforce CLI + Developer Edition org)
1. `sf org login web -a acp && sf project deploy start -o acp`
2. `sf org assign permset -n Account_Case_Panel_User -o acp` (Apex access only; Case access comes from the profile)
3. `sf apex run -f scripts/apex/sample-data.apex -o acp` (one Account with Cases, one without)
4. Lightning App Builder → activate **Account Case Panel Record Page**. Tests: `sf apex run test -n AccountCasePanelControllerTest -c -w 10 -o acp`

**Key decisions**
- Reads use `@wire` + cacheable Apex (`with sharing`, `WITH USER_MODE`); closing uses LDS `updateRecord`, so sharing, FLS and validation rules apply with no write Apex. The action is hidden without edit access to `Case.Status`.
- Counters come from one aggregate query over all Cases; the list is capped at 50 and says so. Filters run in the browser.
- Loading, empty, no-match and error states are explicit: load errors show a custom label, save errors show the platform's message.

**With more time:** closed status from `CaseStatus` (today `'Closed'` is hardcoded), server-side pagination, Jest tests, sortable columns, `lightning/refresh` listener, CI on a scratch org.

