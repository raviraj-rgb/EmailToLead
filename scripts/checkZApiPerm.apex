// Check zApiPermission permission set
List<PermissionSet> ps = [
    SELECT Id, Name, Label
    FROM PermissionSet
    WHERE Name = 'zApiPermission'
];
if (ps.isEmpty()) {
    System.debug('zApiPermission NOT FOUND');
} else {
    System.debug('Found PS: ' + ps[0].Name + ' | Label=' + ps[0].Label + ' | Id=' + ps[0].Id);

    // Who has it assigned?
    List<PermissionSetAssignment> assignments = [
        SELECT Assignee.Username, Assignee.Name, Assignee.Id
        FROM PermissionSetAssignment
        WHERE PermissionSetId = :ps[0].Id
    ];
    System.debug('Assigned to ' + assignments.size() + ' user(s):');
    for (PermissionSetAssignment a : assignments) {
        System.debug('  User: ' + a.Assignee.Name + ' (' + a.Assignee.Username + ') Id=' + a.Assignee.Id);
    }
}

// Check current user
System.debug('Current User: ' + UserInfo.getUserName() + ' Id=' + UserInfo.getUserId());

// Check if current user has zApiPermission
List<PermissionSetAssignment> myPsa = [
    SELECT PermissionSet.Name
    FROM PermissionSetAssignment
    WHERE AssigneeId = :UserInfo.getUserId()
      AND PermissionSet.Name = 'zApiPermission'
];
System.debug('Current user has zApiPermission: ' + (!myPsa.isEmpty()));

// Check Named Credentials
List<NamedCredential> ncs = [
    SELECT Id, DeveloperName, MasterLabel, Endpoint
    FROM NamedCredential
    ORDER BY DeveloperName
];
System.debug('Named Credentials (' + ncs.size() + '):');
for (NamedCredential nc : ncs) {
    System.debug('  NC: ' + nc.DeveloperName + ' | Endpoint=' + nc.Endpoint);
}
