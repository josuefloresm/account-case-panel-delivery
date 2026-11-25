# Account Case Panel

LWC for the Account record page: Case counters, status/priority filters and a "Close Case" action.

**Setup:** `sf org login web -a acp && sf project deploy start -o acp && sf org assign permset -n Account_Case_Panel_User -o acp && sf apex run -f scripts/apex/sample-data.apex -o acp`, then activate **Account Case Panel Record Page** (Setup → Lightning App Builder). Tests: `sf apex run test -n AccountCasePanelControllerTest -c -w 10 -o acp`.

**Key decisions**

- Reads use `@wire` + cacheable Apex (`with sharing`, `WITH USER_MODE`); closing uses LDS `updateRecord`, so sharing, FLS and validation rules apply with no write Apex. The action is hidden without edit access to `Case.Status`.
- Counters come from one aggregate query over all Cases; the list is capped at 50 and says so when counters exceed it. Filters run in the browser over those rows.
- Loading, empty, no-match and error states are explicit; every message is a custom label, so no raw exception reaches the UI.

**With more time:** Jest tests, server-side pagination, closed status from `CaseStatus`, sortable columns, `lightning/refresh` listener, CI on a scratch org.
