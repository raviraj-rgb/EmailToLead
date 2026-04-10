// Check current running user context
System.debug('Running User: ' + UserInfo.getUserName());
System.debug('Running User Id: ' + UserInfo.getUserId());
System.debug('Running User Profile: ' + UserInfo.getProfileId());

// Check all Permission Sets assigned to the current user
List<PermissionSetAssignment> psas = [
    SELECT PermissionSet.Name, PermissionSet.Label, PermissionSet.IsOwnedByProfile
    FROM PermissionSetAssignment
    WHERE AssigneeId = :UserInfo.getUserId()
    ORDER BY PermissionSet.Name
];
System.debug('Permission Sets assigned to current user (' + psas.size() + '):');
for (PermissionSetAssignment psa : psas) {
    System.debug('  PS: ' + psa.PermissionSet.Name + ' | Label=' + psa.PermissionSet.Label + ' | IsProfile=' + psa.PermissionSet.IsOwnedByProfile);
}

// Check all Named Credentials in org
List<NamedCredential> ncs = [
    SELECT Id, DeveloperName, MasterLabel, Endpoint
    FROM NamedCredential
    ORDER BY DeveloperName
];
System.debug('Named Credentials (' + ncs.size() + '):');
for (NamedCredential nc : ncs) {
    System.debug('  NC: ' + nc.DeveloperName + ' | Label=' + nc.MasterLabel + ' | Endpoint=' + nc.Endpoint);
}

// Check External Credentials
List<ExternalCredential> ecs = [
    SELECT Id, DeveloperName, MasterLabel
    FROM ExternalCredential
    ORDER BY DeveloperName
];
System.debug('External Credentials (' + ecs.size() + '):');
for (ExternalCredential ec : ecs) {
    System.debug('  EC: ' + ec.DeveloperName + ' | Label=' + ec.MasterLabel);
}

// Check Permission Sets that contain "Mistral" or "EmailToLead" or "External Credential"
List<PermissionSet> relatedPS = [
    SELECT Id, Name, Label
    FROM PermissionSet
    WHERE Name LIKE '%Mistral%'
       OR Name LIKE '%EmailToLead%'
       OR Name LIKE '%External%'
       OR Name LIKE '%NamedCredential%'
       OR Label LIKE '%Mistral%'
       OR Label LIKE '%EmailToLead%'
    ORDER BY Name
];
System.debug('Related Permission Sets (' + relatedPS.size() + '):');
for (PermissionSet ps : relatedPS) {
    System.debug('  PS: ' + ps.Name + ' | Label=' + ps.Label);

    // Check who has this PS assigned
    List<PermissionSetAssignment> assignments = [
        SELECT Assignee.Username, Assignee.Name
        FROM PermissionSetAssignment
        WHERE PermissionSetId = :ps.Id
    ];
    for (PermissionSetAssignment a : assignments) {
        System.debug('    Assigned to: ' + a.Assignee.Name + ' (' + a.Assignee.Username + ')');
    }
}
