public with sharing class DescribeObjectTool implements IAgentTool {
  public String execute(String paramsJson, AgentUnitOfWork uow) {
    Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(
      paramsJson
    );

    String objectName = (String) params.get('objectName');

    ToolSecurity.validateObject(objectName);

    Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectName);
    if (sot == null) {
      throw new DescribeException('Object not found: ' + objectName);
    }

    Schema.DescribeSObjectResult describe = sot.getDescribe();
    Map<String, Schema.SObjectField> fieldMap = describe.fields.getMap();

    List<Map<String, Object>> fields = new List<Map<String, Object>>();

    for (String fieldName : fieldMap.keySet()) {
      Schema.DescribeFieldResult f = fieldMap.get(fieldName).getDescribe();

      if (f.isAccessible()) {
        fields.add(
          new Map<String, Object>{
            'name' => f.getName(),
            'label' => f.getLabel(),
            'type' => f.getType().name(),
            'required' => !f.isNillable() && f.isCreateable(),
            'updateable' => f.isUpdateable(),
            'createable' => f.isCreateable()
          }
        );
      }
    }

    return JSON.serialize(
      new Map<String, Object>{
        'objectName' => objectName,
        'label' => describe.getLabel(),
        'labelPlural' => describe.getLabelPlural(),
        'keyPrefix' => describe.getKeyPrefix(),
        'fields' => fields
      }
    );
  }

  public Map<String, Object> getDefinition() {
    return new Map<String, Object>{
      'name' => 'describeObject',
      'description' => 'Returns field metadata for an object. Allowed objects: ' + String.join(new List<String>(ToolSecurity.ALLOWED_OBJECTS), ', ') + '.',
      'parameters' => new Map<String, Object>{
        'objectName' => new Map<String, Object>{
          'type' => 'string',
          'description' => 'API name of the object (e.g., Account, Contact, Case)'
        }
      },
      'returns' => new Map<String, Object>{
        'type' => 'object',
        'description' => 'Object metadata including label, keyPrefix, and list of accessible fields with name, label, type, required, updateable, createable'
      }
    };
  }

  public class DescribeException extends Exception {
  }
}
