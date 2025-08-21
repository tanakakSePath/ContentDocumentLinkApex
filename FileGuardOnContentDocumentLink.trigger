// FileGuardOnContentDocumentLink.trigger
trigger FileGuardOnContentDocumentLink on ContentDocumentLink (before insert, before delete) {

    // ▼任意：運用バイパス（カスタム権限）
    if (FeatureManagement.checkPermission('Bypass_File_Guard')) return;

    // ▼▼▼ TODO：対象オブジェクト＆承認判定フィールド＆値を置換 ▼▼▼
    // 例：TARGET_OBJECT__c → J_Project__c、STATUS_FIELD__c → Status__c、'Approved' → '承認済み'
    Schema.SObjectType TARGET_TYPE = TARGET_OBJECT__c.SObjectType;
    String APPROVED_VALUE = 'Approved';
    String ERR_MSG = 'このレコードは承認済みのため、ファイルの追加・削除はできません。';

    // 1) 対象オブジェクトの親IDだけを抽出（他オブジェクトは無視）
    Set<Id> targetParentIds = new Set<Id>();
    if (Trigger.isInsert) {
        for (ContentDocumentLink cdl : Trigger.new) {
            if (cdl.LinkedEntityId != null &&
                cdl.LinkedEntityId.getSObjectType() == TARGET_TYPE) {
                targetParentIds.add(cdl.LinkedEntityId);
            }
        }
    } else if (Trigger.isDelete) {
        for (ContentDocumentLink cdl : Trigger.old) {
            if (cdl.LinkedEntityId != null &&
                cdl.LinkedEntityId.getSObjectType() == TARGET_TYPE) {
                targetParentIds.add(cdl.LinkedEntityId);
            }
        }
    }
    if (targetParentIds.isEmpty()) return; // 対象外：何もしない

    // 2) 対象オブジェクトのうち「承認済み」だけ取得
    Map<Id, SObject> approvedParentMap = new Map<Id, SObject>([
        SELECT Id, STATUS_FIELD__c
        FROM TARGET_OBJECT__c
        WHERE Id IN :targetParentIds
          AND STATUS_FIELD__c = :APPROVED_VALUE
    ]);
    if (approvedParentMap.isEmpty()) return;

    // 3) 承認済み親への新規添付/削除のみブロック
    if (Trigger.isInsert) {
        for (ContentDocumentLink cdl : Trigger.new) {
            if (approvedParentMap.containsKey(cdl.LinkedEntityId)) {
                cdl.addError(ERR_MSG);
            }
        }
    } else if (Trigger.isDelete) {
        for (ContentDocumentLink cdl : Trigger.old) {
            if (approvedParentMap.containsKey(cdl.LinkedEntityId)) {
                cdl.addError(ERR_MSG);
            }
        }
    }
}
