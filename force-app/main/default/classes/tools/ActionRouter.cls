public with sharing class ActionRouter {
  private static final Map<String, String> TOOL_CLASSES = new Map<String, String>{
    'add' => 'AddTool',
    'createRecord' => 'CreateRecordTool',
    'deleteRecords' => 'DeleteRecordsTool',
    'describeObject' => 'DescribeObjectTool',
    'getRecord' => 'GetRecordTool',
    'getRelatedRecords' => 'GetRelatedRecordsTool',
    'queryRecords' => 'QueryRecordsTool',
    'searchRecords' => 'SearchRecordsTool',
    'updateRecord' => 'UpdateRecordTool'
  };

  public static String invoke(String toolName, String toolParams, AgentUnitOfWork uow) {
    if (String.isBlank(toolName)) {
      throw new ActionException('Tool name is required');
    }

    String className = TOOL_CLASSES.get(toolName);
    if (className == null) {
      throw new ActionException(
        'Unknown tool: ' + toolName + '. Available: ' +
        String.join(new List<String>(TOOL_CLASSES.keySet()), ', ')
      );
    }

    Type toolType = Type.forName(className);
    if (toolType == null) {
      throw new ActionException('Tool class not found: ' + className);
    }

    IAgentTool tool = (IAgentTool) toolType.newInstance();
    return tool.execute(toolParams, uow);
  }

  public static List<Map<String, Object>> getAllDefinitions() {
    List<Map<String, Object>> definitions = new List<Map<String, Object>>();
    for (String className : TOOL_CLASSES.values()) {
      Type toolType = Type.forName(className);
      IAgentTool tool = (IAgentTool) toolType.newInstance();
      definitions.add(tool.getDefinition());
    }
    return definitions;
  }

  public class ActionException extends Exception {
  }
}
