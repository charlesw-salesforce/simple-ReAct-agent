public with sharing class AddTool implements IAgentTool {
  public String execute(String paramsJson, AgentUnitOfWork uow) {
    Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(
      paramsJson
    );
    Decimal a = (Decimal) params.get('a');
    Decimal b = (Decimal) params.get('b');
    return JSON.serialize(a + b);
  }

  public Map<String, Object> getDefinition() {
    return new Map<String, Object>{
      'name' => 'add',
      'description' => 'Adds two numbers and returns the sum',
      'parameters' => new Map<String, Object>{
        'a' => new Map<String, Object>{
          'type' => 'number',
          'description' => 'First number'
        },
        'b' => new Map<String, Object>{
          'type' => 'number',
          'description' => 'Second number'
        }
      },
      'returns' => new Map<String, Object>{
        'type' => 'number',
        'description' => 'The sum of a and b'
      }
    };
  }
}
