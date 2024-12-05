# SpendRouter

The SpendRouter is a singleton contract that executes token spends based on permissions granted through the SpendPermissionManager and routes the spend to a configurable recipient. It acts as a secure intermediary between spending applications and user accounts, guaranteeing that the spend is routed to the correct recipient, and that the spend can only be initiated by a specific address.
