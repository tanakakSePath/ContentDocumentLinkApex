// Optional: FileGuardOnContentDocument.trigger
trigger FileGuardOnContentDocument on ContentDocument (before delete) {

    if (FeatureManagement.checkPermission('Bypass_File_Guard')) return;

    // ▼▼▼ TODO：対象オブジェクト＆承認判定フィールド＆値を置換 ▼▼▼
    Schema.SObjectType TARGET_TYPE = TARGET_OBJECT__c.SObjectType;
    String APPROVED_VALUE = 'Approved';
    String ERR_MSG = '承認済みのレコードに関連付くため、ファイル本体の削除はできません。';

    Set<Id> docIds = new Set<Id>();
    for (ContentDocument cd : Trigger.old) docIds.add(cd.Id);
    if (docIds.isEmpty()) return;

    // 1) 対象オブジェクトに紐づくリンクだけ拾う
    Map<Id, Set<Id>> docIdToTargetParentIds = new Map<Id, Set<Id>>();
    for (ContentDocumentLink cdl : [
        SELECT ContentDocumentId, LinkedEntityId
        FROM ContentDocumentLink
        WHERE ContentDocumentId IN :docIds
    ]) {
        if (cdl.LinkedEntityId != null &&
            cdl.LinkedEntityId.getSObjectType() == TARGET_TYPE) {
            docIdToTargetParentIds.putIfAbsent(cdl.ContentDocumentId, new Set<Id>());
            docIdToTargetParentIds.get(cdl.ContentDocumentId).add(cdl.LinkedEntityId);
        }
    }
    if (docIdToTargetParentIds.isEmpty()) return; // 対象外ファイルのみ → 何もしない

    // 2) 対象親のうち承認済みを抽出
    Set<Id> parentIds = new Set<Id>();
    for (Set<Id> ids : docIdToTargetParentIds.values()) parentIds.addAll(ids);

    Set<Id> approvedParents = new Map<Id, SObject>([
        SELECT Id, STATUS_FIELD__c
        FROM TARGET_OBJECT__c
        WHERE Id IN :parentIds
          AND STATUS_FIELD__c = :APPROVED_VALUE
    ]).keySet();
    if (approvedParents.isEmpty()) return;

    // 3) 承認済み親に紐づくファイルだけ削除ブロック
    for (ContentDocument cd : Trigger.old) {
        Set<Id> parents = docIdToTargetParentIds.get(cd.Id);
        if (parents != null) {
            for (Id pid : parents) {
                if (approvedParents.contains(pid)) {
                    cd.addError(ERR_MSG);
                    break;
                }
            }
        }
    }
}
