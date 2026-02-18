public with sharing class GetRecordTool implements IAgentTool {
  public String execute(String paramsJson, AgentUnitOfWork uow) {
    Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(
      paramsJson
    );

    String recordId = (String) params.get('recordId');
    List<Object> fieldsRaw = (List<Object>) params.get('fields');

    Id recId = (Id) recordId;
    String objectName = recId.getSObjectType().getDescribe().getName();

    ToolSecurity.validateObject(objectName);

    List<String> fields = new List<String>();
    for (Object f : fieldsRaw) {
      fields.add((String) f);
    }

    ToolSecurity.validateFieldsAccessible(objectName, fields);

    String query =
      'SELECT ' +
      String.join(fields, ', ') +
      ' FROM ' +
      objectName +
      ' WHERE Id = :recId LIMIT 1';

    List<SObject> records = Database.query(query);

    if (records.isEmpty()) {
      throw new GetRecordException('Record not found: ' + recordId);
    }

    SObject record = records[0];
    Map<String, Object> recordMap = new Map<String, Object>();
    for (String field : fields) {
      recordMap.put(field, record.get(field));
    }

    return JSON.serialize(recordMap);
  }

  public Map<String, Object> getDefinition() {
    return new Map<String, Object>{
      'name' => 'getRecord',
      'description' => 'Retrieves a single record by Id with specified fields. Allowed objects: ' + String.join(new List<String>(ToolSecurity.ALLOWED_OBJECTS), ', ') + '.',
      'parameters' => new Map<String, Object>{
        'recordId' => new Map<String, Object>{
          'type' => 'string',
          'description' => 'The Salesforce record Id'
        },
        'fields' => new Map<String, Object>{
          'type' => 'array',
          'description' => 'Array of field API names to retrieve (e.g., ["Id", "Name", "Email", "Phone"])'
        }
      },
      'returns' => new Map<String, Object>{
        'type' => 'object',
        'description' => 'Record with requested fields'
      }
    };
  }

  public class GetRecordException extends Exception {
  }
}
