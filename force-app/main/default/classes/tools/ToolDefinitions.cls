public with sharing class ToolDefinitions {
  private static String cachedDefinitions;

  public static String getDefinitionsJson() {
    if (cachedDefinitions == null) {
      cachedDefinitions = JSON.serialize(ActionRouter.getAllDefinitions());
    }
    return cachedDefinitions;
  }
}
