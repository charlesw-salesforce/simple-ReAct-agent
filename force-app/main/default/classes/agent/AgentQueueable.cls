/**
 * ReAct (Reasoning + Acting) agent loop using recursive queueable jobs.
 *
 * Each iteration: calls LLM -> executes tools -> recurses until answer or max iterations (4).
 * Publishes AgentStep__e events for real-time UI updates. Supports user stop requests.
 */
public with sharing class AgentQueueable implements Queueable, Database.AllowsCallouts {
  private String sessionId;
  private String userMessage;
  private List<Map<String, Object>> conversationHistory;
  private List<Map<String, Object>> previousSteps;
  private Integer iteration;
  private static final Integer MAX_ITERATIONS = 4;
  private static final String TEMPLATE = 'Agentic_Template';
  private static final String SYSTEM_MESSAGE = AgentConfig__mdt.getInstance('Default').SystemMessage__c;

  /**
   * @param sessionId Agent session identifier
   * @param userMessage Original user message
   * @param conversationHistory Chat history with role/content maps
   * @param previousSteps ReAct steps: [{thought, toolCalls, results}]
   * @param iteration Current iteration (0-indexed)
   */
  public AgentQueueable(
    String sessionId,
    String userMessage,
    List<Map<String, Object>> conversationHistory,
    List<Map<String, Object>> previousSteps,
    Integer iteration
  ) {
    this.sessionId = sessionId;
    this.userMessage = userMessage;
    this.conversationHistory = conversationHistory;
    this.previousSteps = previousSteps;
    this.iteration = iteration;
  }

  /**
   * Executes one agent iteration: check stop -> call LLM -> parse output ->
   * execute tools OR publish final answer -> recurse if needed.
   */
  public void execute(QueueableContext context) {
    try {
      // Check if stop was requested
      List<AgentSession__c> sessions = [
        SELECT StopRequested__c
        FROM AgentSession__c
        WHERE SessionId__c = :sessionId
        LIMIT 1
      ];
      if (!sessions.isEmpty() && sessions[0].StopRequested__c) {
        publishEvent(
          new AgentStep__e(
            SessionId__c = sessionId,
            Answer__c = 'Stopped by user.',
            Status__c = 'STOPPED'
          )
        );
        return;
      }

      // Call LLM via Prompt Builder
      String systemMessageWithIteration = SYSTEM_MESSAGE +
        '\n\nCurrent iteration: ' + (iteration + 1) + ' of ' + MAX_ITERATIONS +
        '. You have ' + (MAX_ITERATIONS - iteration) + ' iteration(s) remaining.';

      Object structuredResponse = PromptService.invoke(
        TEMPLATE,
        new Map<String, String>{
          'systemContext' => systemMessageWithIteration,
          'tools' => ToolDefinitions.getDefinitionsJson(),
          'conversationHistory' => JSON.serialize(conversationHistory),
          'previousSteps' => JSON.serialize(previousSteps),
          'userMessage' => userMessage
        }
      );

      // Convert structured response (Lightning Type) to AgentOutput
      AgentOutput output = (AgentOutput) JSON.deserialize(
        JSON.serialize(structuredResponse),
        AgentOutput.class
      );

      // Done if answer provided or max iterations reached
      if (String.isNotBlank(output.answer) || iteration >= MAX_ITERATIONS) {
        String finalAnswer = String.isNotBlank(output.answer)
          ? output.answer
          : 'Unable to complete within allowed steps.';

        conversationHistory.add(
          new Map<String, Object>{
            'role' => 'assistant',
            'content' => finalAnswer
          }
        );

        publishEvent(
          new AgentStep__e(
            SessionId__c = sessionId,
            Thought__c = output.thought,
            Utterance__c = output.utterance,
            Answer__c = finalAnswer,
            Status__c = 'COMPLETE'
          )
        );
        return;
      }

      // Execute tool calls and recurse
      AgentUnitOfWork uow = new AgentUnitOfWork();
      List<Map<String, Object>> toolCalls = output.getToolCallsList();
      List<String> toolResults = new List<String>();

      // Execute all tool calls
      for (Map<String, Object> call : toolCalls) {
        String toolName = (String) call.get('toolName');
        Object paramsObj = call.get('toolParameters');
        String toolParams = (paramsObj instanceof String)
          ? (String) paramsObj
          : JSON.serialize(paramsObj);

        try {
          String result = ActionRouter.invoke(toolName, toolParams, uow);
          toolResults.add(toolName + ': ' + result);
        } catch (Exception e) {
          toolResults.add(toolName + ': ERROR - ' + e.getMessage());
        }
      }

      // Commit DML operations
      if (!uow.isEmpty()) {
        uow.commitWork();

        // Add record IDs to results so agent knows what was created/updated
        String commitSummary = uow.getCommitSummary();
        if (String.isNotBlank(commitSummary)) {
          toolResults.add(commitSummary);
        }
      }

      String aggregatedResult = String.join(toolResults, ' | ');

      List<String> toolNames = new List<String>();
      for (Map<String, Object> call : toolCalls) {
        toolNames.add((String) call.get('toolName'));
      }

      // Publish tool call results
      publishEvent(
        new AgentStep__e(
          SessionId__c = sessionId,
          Thought__c = output.thought,
          Utterance__c = output.utterance,
          ToolName__c = String.join(toolNames, ', '),
          ToolResult__c = aggregatedResult,
          Status__c = 'IN_PROGRESS'
        )
      );

      // Add step to history
      previousSteps.add(
        new Map<String, Object>{
          'thought' => output.thought,
          'toolCalls' => toolCalls,
          'results' => toolResults
        }
      );

      // Enqueue next iteration
      System.enqueueJob(
        new AgentQueueable(
          sessionId,
          userMessage,
          conversationHistory,
          previousSteps,
          iteration + 1
        )
      );
    } catch (Exception e) {
      publishEvent(
        new AgentStep__e(
          SessionId__c = sessionId,
          Answer__c = 'Error: ' + e.getMessage(),
          Status__c = 'ERROR'
        )
      );
    }
  }

  private void publishEvent(AgentStep__e event) {
    Database.SaveResult sr = EventBus.publish(event);
    if (!sr.isSuccess()) {
      System.debug(
        LoggingLevel.ERROR,
        'Failed to publish AgentStep__e: ' + sr.getErrors()[0].getMessage()
      );
    }
  }
}
