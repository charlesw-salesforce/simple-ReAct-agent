public interface IAgentTool {
  String execute(String paramsJson, AgentUnitOfWork uow);
  Map<String, Object> getDefinition();
}
