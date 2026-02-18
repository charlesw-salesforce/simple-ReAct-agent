public with sharing class AgentSessionService {
  public static void ensureSession(String sessionId) {
    if (String.isBlank(sessionId)) {
      return;
    }

    AgentSession__c session = new AgentSession__c(
      SessionId__c = sessionId,
      StopRequested__c = false
    );
    upsert session SessionId__c;
  }

  public static void requestStop(String sessionId) {
    if (String.isBlank(sessionId)) {
      return;
    }

    AgentSession__c session = new AgentSession__c(
      SessionId__c = sessionId,
      StopRequested__c = true
    );
    upsert session SessionId__c;
  }

  public static Boolean isStopRequested(String sessionId) {
    if (String.isBlank(sessionId)) {
      return false;
    }

    List<AgentSession__c> sessions = [
      SELECT StopRequested__c
      FROM AgentSession__c
      WHERE SessionId__c = :sessionId
      WITH USER_MODE 
      LIMIT 1
    ];
    return !sessions.isEmpty() && sessions[0].StopRequested__c;
  }
}
