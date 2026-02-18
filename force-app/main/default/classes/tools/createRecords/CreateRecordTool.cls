public with sharing class CreateRecordTool implements IAgentTool {
  public String execute(String paramsJson, AgentUnitOfWork uow) {
    Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(
      paramsJson
    );

    String objectName = (String) params.get('objectName');
    List<Object> recordsRaw = (List<Object>) params.get('records');

    ToolSecurity.validateObject(objectName);

    Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectName);
    if (sot == null) {
      throw new CreateRecordException('Object not found: ' + objectName);
    }

    Schema.DescribeSObjectResult objDescribe = sot.getDescribe();
    if (!objDescribe.isCreateable()) {
      throw new CreateRecordException(
        'You do not have permission to create ' + objectName + ' records.'
      );
    }

    Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();

    Integer count = 0;
    for (Object recordObj : recordsRaw) {
      Map<String, Object> fields = (Map<String, Object>) recordObj;

      List<String> deniedFields = new List<String>();
      for (String fieldName : fields.keySet()) {
        Schema.SObjectField sField = fieldMap.get(fieldName.toLowerCase());
        if (sField == null || !sField.getDescribe().isCreateable()) {
          deniedFields.add(fieldName);
        }
      }
      if (!deniedFields.isEmpty()) {
        throw new CreateRecordException(
          'Fields not createable: ' + String.join(deniedFields, ', ')
        );
      }

      SObject record = sot.newSObject();
      for (String fieldName : fields.keySet()) {
        Schema.SObjectField sField = fieldMap.get(fieldName.toLowerCase());
        Object coerced = FieldCoercion.toFieldValue(fields.get(fieldName), sField.getDescribe());
        record.put(fieldName, coerced);
      }
      uow.registerInsert(record);
      count++;
    }

    return JSON.serialize(
      new Map<String, Object>{
        'success' => true,
        'objectName' => objectName,
        'count' => count,
        'status' => 'queued'
      }
    );
  }

  public Map<String, Object> getDefinition() {
    return new Map<String, Object>{
      'name' => 'createRecord',
      'description' => 'Creates one or more records. Allowed objects: ' + String.join(new List<String>(ToolSecurity.ALLOWED_OBJECTS), ', ') + '.',
      'parameters' => new Map<String, Object>{
        'objectName' => new Map<String, Object>{
          'type' => 'string',
          'description' => 'API name of the object (e.g., Account, Contact, Case)'
        },
        'records' => new Map<String, Object>{
          'type' => 'array',
          'description' => 'Array of field maps. Each element is an object with field API names as keys (e.g., [{"Name": "Acme"}, {"Name": "Globex"}])'
        }
      },
      'returns' => new Map<String, Object>{
        'type' => 'object',
        'description' => 'Object with success boolean, count, and status'
      }
    };
  }

  public class CreateRecordException extends Exception {
  }
}
