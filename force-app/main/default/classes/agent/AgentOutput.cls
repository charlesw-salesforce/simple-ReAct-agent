/**
 * Companion class for parsing AgentOutput from Prompt Template.
 *
 * IMPORTANT: Create a Lightning Type in Prompt Builder with the same field names.
 * Use each field's comment below as the "description" in the Lightning Type definition.
 */
public class AgentOutput {
  /**
   * Description for Lightning Type:
   * "Your internal reasoning about the current situation and what to do next. Never shown to the user."
   */
  @AuraEnabled
  public String thought;

  /**
   * Description for Lightning Type:
   * "A brief, natural message to the user about what you are doing. Shown in real-time. Empty string if not needed."
   */
  @AuraEnabled
  public String utterance;

  /**
   * Description for Lightning Type:
   * "Your final response to the user as an HTML string. Empty string if invoking a tool."
   */
  @AuraEnabled
  public String answer;

  /**
   * Description for Lightning Type:
   * "A JSON-encoded array of tool call objects to invoke. Each object must contain 'toolName' (the tool to invoke) and 'toolParameters' (a JSON object of the tool's input parameters). You may include multiple objects to invoke tools in parallel. Empty array if providing a final answer."
   */
  @AuraEnabled
  public String toolCalls;

  public List<Map<String, Object>> getToolCallsList() {
    List<Map<String, Object>> calls = new List<Map<String, Object>>();

    if (String.isNotBlank(toolCalls)) {
      try {
        List<Object> parsed = (List<Object>) JSON.deserializeUntyped(toolCalls);
        for (Object obj : parsed) {
          if (obj instanceof Map<String, Object>) {
            calls.add((Map<String, Object>) obj);
          }
        }
      } catch (Exception e) {
        System.debug('Error parsing toolCalls JSON: ' + e.getMessage());
      }
    }

    return calls;
  }

  public Boolean hasToolCalls() {
    return !getToolCallsList().isEmpty();
  }
}
