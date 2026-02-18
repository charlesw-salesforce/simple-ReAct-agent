public with sharing class QueryRecordsTool implements IAgentTool {
  private static final Integer MAX_RESULTS = 100;

  public String execute(String paramsJson, AgentUnitOfWork uow) {
    Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(
      paramsJson
    );

    String objectName = (String) params.get('objectName');
    List<Object> fieldsRaw = (List<Object>) params.get('fields');
    String whereClause = (String) params.get('where');
    String orderBy = (String) params.get('orderBy');
    Integer limitCount = params.get('limit') != null
      ? (Integer) params.get('limit')
      : 50;

    if (limitCount > MAX_RESULTS) {
      limitCount = MAX_RESULTS;
    }

    ToolSecurity.validateObject(objectName);

    List<String> fields = new List<String>();
    for (Object f : fieldsRaw) {
      fields.add((String) f);
    }

    ToolSecurity.validateFieldsAccessible(objectName, fields);

    String query = 'SELECT ' + String.join(fields, ', ') + ' FROM ' + objectName;

    if (String.isNotBlank(whereClause)) {
      query += ' WHERE ' + whereClause;
    }

    if (String.isNotBlank(orderBy)) {
      query += ' ORDER BY ' + sanitizeOrderBy(objectName, orderBy);
    }

    query += ' LIMIT ' + limitCount;

    List<SObject> records = Database.query(query);

    List<Map<String, Object>> results = new List<Map<String, Object>>();
    for (SObject record : records) {
      Map<String, Object> recordMap = new Map<String, Object>();
      for (String field : fields) {
        recordMap.put(field, record.get(field));
      }
      results.add(recordMap);
    }

    return JSON.serialize(
      new Map<String, Object>{ 'records' => results, 'count' => results.size() }
    );
  }

  /**
   * Parses and reconstructs the ORDER BY clause using only validated field names
   * and known SOQL modifiers (ASC, DESC, NULLS FIRST, NULLS LAST).
   */
  private String sanitizeOrderBy(String objectName, String orderBy) {
    List<String> validatedParts = new List<String>();

    for (String part : orderBy.split(',')) {
      List<String> tokens = part.trim().split('\\s+');
      String fieldName = tokens[0];

      ToolSecurity.validateFieldsAccessible(objectName, new List<String>{ fieldName });

      String rebuilt = fieldName;
      if (tokens.size() > 1) {
        String mod = tokens[1].toUpperCase();
        if (mod == 'ASC' || mod == 'DESC') {
          rebuilt += ' ' + mod;
        }
      }
      if (tokens.size() > 3) {
        String nullsKeyword = tokens[2].toUpperCase();
        String nullsDir = tokens[3].toUpperCase();
        if (nullsKeyword == 'NULLS' && (nullsDir == 'FIRST' || nullsDir == 'LAST')) {
          rebuilt += ' NULLS ' + nullsDir;
        }
      }
      validatedParts.add(rebuilt);
    }

    return String.join(validatedParts, ', ');
  }

  public Map<String, Object> getDefinition() {
    return new Map<String, Object>{
      'name' => 'queryRecords',
      'description' => 'Query records using filters, ordering, and limits. Returns up to 100 records. Allowed objects: ' + String.join(new List<String>(ToolSecurity.ALLOWED_OBJECTS), ', ') + '.',
      'parameters' => new Map<String, Object>{
        'objectName' => new Map<String, Object>{
          'type' => 'string',
          'description' => 'API name of the object (e.g., Account, Contact, Case)'
        },
        'fields' => new Map<String, Object>{
          'type' => 'array',
          'description' => 'Array of field API names to retrieve (e.g., ["Id", "Name", "Email"])'
        },
        'where' => new Map<String, Object>{
          'type' => 'string',
          'description' => 'WHERE clause without the WHERE keyword (e.g., "Status = \'Open\' AND Priority = \'High\'")'
        },
        'orderBy' => new Map<String, Object>{
          'type' => 'string',
          'description' => 'ORDER BY clause without ORDER BY keyword (e.g., "CreatedDate DESC")'
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

  public class QueryException extends Exception {
  }
}
