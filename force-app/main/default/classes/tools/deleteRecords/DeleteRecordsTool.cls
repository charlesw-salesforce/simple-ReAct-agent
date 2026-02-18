public with sharing class DeleteRecordsTool implements IAgentTool {
  public String execute(String paramsJson, AgentUnitOfWork uow) {
    Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(
      paramsJson
    );

    List<Object> recordIdsRaw = (List<Object>) params.get('recordIds');

    Integer count = 0;
    for (Object idObj : recordIdsRaw) {
      String recordId = (String) idObj;
      Id recId = (Id) recordId;
      String objectName = recId.getSObjectType().getDescribe().getName();

      ToolSecurity.validateObject(objectName);

      Schema.DescribeSObjectResult objDescribe = recId.getSObjectType()
        .getDescribe();
      if (!objDescribe.isDeletable()) {
        throw new DeleteRecordException(
          'You do not have permission to delete ' + objectName + ' records.'
        );
      }

      SObject record = recId.getSObjectType().newSObject(recId);
      uow.registerDelete(record);
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
      'name' => 'deleteRecords',
      'description' => 'Deletes one or more records by Id. Allowed objects: ' + String.join(new List<String>(ToolSecurity.ALLOWED_OBJECTS), ', ') + '.',
      'parameters' => new Map<String, Object>{
        'recordIds' => new Map<String, Object>{
          'type' => 'array',
          'description' => 'Array of record Ids to delete (e.g., ["001...", "001..."])'
        }
      },
      'returns' => new Map<String, Object>{
        'type' => 'object',
        'description' => 'Object with success boolean, count, and status'
      }
    };
  }

  public class DeleteRecordException extends Exception {
  }
}
