public with sharing class GetRelatedRecordsTool implements IAgentTool {
  private static final Integer MAX_RESULTS = 100;

  public String execute(String paramsJson, AgentUnitOfWork uow) {
    Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(
      paramsJson
    );

    String recordId = (String) params.get('recordId');
    String relationshipName = (String) params.get('relationshipName');
    List<Object> fieldsRaw = (List<Object>) params.get('fields');
    Integer limitCount = params.get('limit') != null
      ? (Integer) params.get('limit')
      : 50;

    if (limitCount > MAX_RESULTS) {
      limitCount = MAX_RESULTS;
    }

    Id recId = (Id) recordId;
    String parentObjectName = recId.getSObjectType().getDescribe().getName();

    ToolSecurity.validateObject(parentObjectName);

    String childObjectName = ToolSecurity.validateRelationship(
      parentObjectName, relationshipName
    );

    List<String> fields = new List<String>();
    for (Object f : fieldsRaw) {
      fields.add((String) f);
    }

    ToolSecurity.validateFieldsAccessible(childObjectName, fields);

    // Use subquery to get related records — field names and relationship name
    // are validated against the schema above
    String query =
      'SELECT Id, (SELECT ' +
      String.join(fields, ', ') +
      ' FROM ' +
      relationshipName +
      ' LIMIT ' +
      limitCount +
      ') FROM ' +
      parentObjectName +
      ' WHERE Id = :recId';

    List<SObject> parentRecords = Database.query(query);

    if (parentRecords.isEmpty()) {
      throw new GetRelatedRecordsException('Parent record not found: ' + recordId);
    }

    SObject parentRecord = parentRecords[0];
    List<SObject> childRecords = parentRecord.getSObjects(relationshipName);

    List<Map<String, Object>> results = new List<Map<String, Object>>();
    if (childRecords != null) {
      for (SObject record : childRecords) {
        Map<String, Object> recordMap = new Map<String, Object>();
        for (String field : fields) {
          recordMap.put(field, record.get(field));
        }
        results.add(recordMap);
      }
    }

    return JSON.serialize(
      new Map<String, Object>{ 'records' => results, 'count' => results.size() }
    );
  }

  public Map<String, Object> getDefinition() {
    return new Map<String, Object>{
      'name' => 'getRelatedRecords',
      'description' => 'Retrieves child records via a relationship field. For example, get all Contacts for an Account, or all Cases for a Contact. Allowed parent objects: ' + String.join(new List<String>(ToolSecurity.ALLOWED_OBJECTS), ', ') + '.',
      'parameters' => new Map<String, Object>{
        'recordId' => new Map<String, Object>{
          'type' => 'string',
          'description' => 'Parent record Id'
        },
        'relationshipName' => new Map<String, Object>{
          'type' => 'string',
          'description' => 'Child relationship name (e.g., "Contacts" for Account.Contacts, "Cases" for Contact.Cases)'
        },
        'fields' => new Map<String, Object>{
          'type' => 'array',
          'description' => 'Array of field API names to retrieve from child records (e.g., ["Name", "Email", "Phone"])'
        },
        'limit' => new Map<String, Object>{
          'type' => 'number',
          'description' => 'Maximum records to return (default 50, max 100)'
        }
      },
      'returns' => new Map<String, Object>{
        'type' => 'object',
        'description' => 'Object with records array and count'
      }
    };
  }

  public class GetRelatedRecordsException extends Exception {
  }
}
