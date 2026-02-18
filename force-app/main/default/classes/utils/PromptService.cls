public with sharing class PromptService {
  public static Object invoke(
    String templateApiName,
    Map<String, String> freeTextInputs
  ) {
    Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();

    for (String key : freeTextInputs.keySet()) {
      ConnectApi.WrappedValue w = new ConnectApi.WrappedValue();
      w.value = freeTextInputs.get(key);
      inputParams.put('Input:' + key, w);
    }

    ConnectApi.EinsteinPromptTemplateGenerationsInput input = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
    input.inputParams = inputParams;
    input.isPreview = false;
    input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
    input.additionalConfig.applicationName = 'PromptBuilderPreview';
    input.additionalConfig.numGenerations = 1;

    ConnectApi.EinsteinPromptTemplateGenerationsRepresentation result = ConnectApi.EinsteinLlm.generateMessagesForPromptTemplate(
      templateApiName,
      input
    );

    return result.generations[0].structuredResponse;
  }
}
