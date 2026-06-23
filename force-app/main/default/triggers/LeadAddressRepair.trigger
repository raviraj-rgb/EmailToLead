trigger LeadAddressRepair on Lead (after insert) {
    List<Id> toRepair = new List<Id>();
    for (Lead l : Trigger.new) {
        if (l.EmailToLead_Ai__Is_Lead_Created_From_Email__c == true
                && l.LeadSource == 'LSI'
                && String.isBlank(l.Project_City__c)
                && !String.isBlank(l.EmailToLead_Ai__emailBody__c)) {
            toRepair.add(l.Id);
        }
    }
    if (!toRepair.isEmpty()) {
        LeadAddressRepairService.repair(toRepair);
    }
}
