public with sharing class SearchRecordsTool implements IAgentTool {
  private static final Integer MAX_RESULTS = 50;

  public String execute(String paramsJson, AgentUnitOfWork uow) {
    Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(
      paramsJson
    );

    String searchTerm = (String) params.get('searchTerm');
    List<Object> objectsRaw = (List<Object>) params.get('objects');

    if (String.isBlank(searchTerm) || searchTerm.length() < 2) {
      throw new SearchException('Search term must be at least 2 characters');
    }

    List<String> objects = new List<String>();
    if (objectsRaw != null) {
      for (Object o : objectsRaw) {
        String objName = (String) o;
        ToolSecurity.validateObject(objName);
        objects.add(objName);
      }
    }

    if (objects.isEmpty()) {
      objects.addAll(
        new List<String>{ 'Account', 'Contact', 'Case', 'Opportunity', 'Lead' }
      );
    }

    String searchQuery =
      'FIND \'' +
      String.escapeSingleQuotes(searchTerm) +
      '*\' IN ALL FIELDS RETURNING ';

    List<String> returnClauses = new List<String>();
    for (String obj : objects) {
      returnClauses.add(obj + '(Id, Name LIMIT 10)');
    }
    searchQuery += String.join(returnClauses, ', ');

    List<List<SObject>> searchResults = Search.query(searchQuery);

    Map<String, List<Map<String, Object>>> results = new Map<String, List<Map<String, Object>>>();

    for (Integer i = 0; i < objects.size(); i++) {
      String objName = objects[i];
      List<Map<String, Object>> records = new List<Map<String, Object>>();

      if (i < searchResults.size()) {
        for (SObject record : searchResults[i]) {
          records.add(
            new Map<String, Object>{
              'Id' => record.Id,
              'Name' => record.get('Name')
            }
          );
        }
      }
      results.put(objName, records);
    }

    return JSON.serialize(results);
  }

  public Map<String, Object> getDefinition() {
    return new Map<String, Object>{
      'name' => 'searchRecords',
      'description' => 'Searches across multiple objects using SOSL. Returns matching records with Id and Name. Allowed objects: ' + String.join(new List<String>(ToolSecurity.ALLOWED_OBJECTS), ', ') + '.',
      'parameters' => new Map<String, Object>{
        'searchTerm' => new Map<String, Object>{
          'type' => 'string',
          'description' => 'Text to search for (minimum 2 characters)'
        },
        'objects' => new Map<String, Object>{
          'type' => 'array',
          'description' => 'List of object API names to search (e.g., ["Account", "Contact"]). Defaults to Account, Contact, Case, Opportunity, Lead if not specified.'
        }
      },
      'returns' => new Map<String, Object>{
        'type' => 'object',
        'description' => 'Map of object names to arrays of matching records with Id and Name'
      }
    };
  }

  public class SearchException extends Exception {
  }
}
