trigger ContactTrigger on Contact (after insert, after update, before delete, after delete, after undelete) {
    if (Trigger.isInsert) {
        if (Trigger.isBefore) {
            ContactTriggerHandler.onBeforeInsert(Trigger.new);
        } else if (Trigger.isAfter) {
            ContactTriggerHandler.onAfterInsert(Trigger.new);
        }
    } else if (Trigger.isUpdate) {
        if (Trigger.isBefore) {
            ContactTriggerHandler.onBeforeUpdate();
        } else if (Trigger.isAfter) {
            ContactTriggerHandler.onAfterUpdate(Trigger.old, Trigger.oldMap, Trigger.new, Trigger.newMap);
        }
    } else if (Trigger.isDelete) {
        if (Trigger.isBefore) {
            ContactTriggerHandler.onBeforeDelete(Trigger.old);
        } else if (Trigger.isAfter) {
            ContactTriggerHandler.onAfterDelete(Trigger.old);
        }
    } else if (Trigger.isUndelete) {
        // Since the requirement doesn't talk about this scenario, so we don't handle the case when an-active-contact-having-parent-account is restored
    }
}