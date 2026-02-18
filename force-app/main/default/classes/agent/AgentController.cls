public with sharing class AgentController {
  @AuraEnabled
  public static String startAgent(
    String sessionId,
    String userMessage,
    String conversationHistoryJson
  ) {
    try {
      // Parse conversation history
      List<Map<String, Object>> conversationHistory = new List<Map<String, Object>>();
      if (String.isNotBlank(conversationHistoryJson)) {
        List<Object> historyRaw = (List<Object>) JSON.deserializeUntyped(conversationHistoryJson);
        for (Object item : historyRaw) {
          conversationHistory.add((Map<String, Object>) item);
        }
      }

      // Generate sessionId if needed
      if (String.isBlank(sessionId)) {
        sessionId = EncodingUtil.convertToHex(Crypto.generateAesKey(128));
      }

      // Create/reset session
      upsert new AgentSession__c(
        SessionId__c = sessionId,
        StopRequested__c = false
      ) SessionId__c;

      // Start agent
      System.enqueueJob(
        new AgentQueueable(
          sessionId,
          userMessage,
          conversationHistory,
          new List<Map<String, Object>>(),
          0
        )
      );

      return sessionId;
    } catch (Exception e) {
      throw new AuraHandledException('Failed to start agent: ' + e.getMessage());
    }
  }

  @AuraEnabled
  public static void stopAgent(String sessionId) {
    try {
      if (String.isBlank(sessionId)) {
        return;
      }

      upsert new AgentSession__c(
        SessionId__c = sessionId,
        StopRequested__c = true
      ) SessionId__c;
    } catch (Exception e) {
      throw new AuraHandledException('Failed to stop agent: ' + e.getMessage());
    }
  }
}
