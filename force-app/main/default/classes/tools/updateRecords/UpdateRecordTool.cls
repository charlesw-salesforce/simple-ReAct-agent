public with sharing class UpdateRecordTool implements IAgentTool {
  public String execute(String paramsJson, AgentUnitOfWork uow) {
    Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(
      paramsJson
    );

    List<Object> updatesRaw = (List<Object>) params.get('updates');

    Integer count = 0;
    for (Object updateObj : updatesRaw) {
      Map<String, Object> updateData = (Map<String, Object>) updateObj;
      String recordId = (String) updateData.get('id');
      Map<String, Object> fields = (Map<String, Object>) updateData.get('fields');

      Id recId = (Id) recordId;
      String objectName = recId.getSObjectType().getDescribe().getName();

      ToolSecurity.validateObject(objectName);

      Schema.DescribeSObjectResult objDescribe = recId.getSObjectType()
        .getDescribe();
      if (!objDescribe.isUpdateable()) {
        throw new UpdateRecordException(
          'You do not have permission to update ' + objectName + ' records.'
        );
      }

      Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();
      List<String> deniedFields = new List<String>();
      for (String fieldName : fields.keySet()) {
        Schema.SObjectField sField = fieldMap.get(fieldName.toLowerCase());
        if (sField == null || !sField.getDescribe().isUpdateable()) {
          deniedFields.add(fieldName);
        }
      }
      if (!deniedFields.isEmpty()) {
        throw new UpdateRecordException(
          'Fields not updateable: ' + String.join(deniedFields, ', ')
        );
      }

      SObject record = recId.getSObjectType().newSObject(recId);
      for (String fieldName : fields.keySet()) {
        Schema.SObjectField sField = fieldMap.get(fieldName.toLowerCase());
        Object coerced = FieldCoercion.toFieldValue(fields.get(fieldName), sField.getDescribe());
        record.put(fieldName, coerced);
      }
      uow.registerUpdate(record);
      count++;
    }

    return JSON.serialize(
      new Map<String, Object>{
        'success' => true,
        'count' => count,
        'status' => 'queued'
      }
    );
  }

  public Map<String, Object> getDefinition() {
    return new Map<String, Object>{
      'name' => 'updateRecord',
      'description' => 'Updates one or more existing records. Allowed objects: ' + String.join(new List<String>(ToolSecurity.ALLOWED_OBJECTS), ', ') + '.',
      'parameters' => new Map<String, Object>{
        'updates' => new Map<String, Object>{
          'type' => 'array',
          'description' => 'Array of updates. Each element has "id" (record Id) and "fields" (map of field names to values). Example: [{"id": "001...", "fields": {"Status": "Closed"}}]'
        }
      },
      'returns' => new Map<String, Object>{
        'type' => 'object',
        'description' => 'Object with success boolean, count, and status'
      }
    };
  }

  public class UpdateRecordException extends Exception {
  }
}
