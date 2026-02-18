public with sharing class ToolSecurity {
  public static final Set<String> ALLOWED_OBJECTS = new Set<String>{
    'Account',
    'Contact',
    'Case',
    'Opportunity',
    'Lead',
    'Task',
    'Event',
    'OpportunityContactRole'
  };

  public static void validateObject(String objectName) {
    if (String.isBlank(objectName) || !ALLOWED_OBJECTS.contains(objectName)) {
      throw new ToolSecurityException(
        'Object not allowed: ' + objectName +
        '. Allowed: ' + String.join(new List<String>(ALLOWED_OBJECTS), ', ')
      );
    }
  }

  public static Schema.DescribeSObjectResult describeObject(String objectName) {
    validateObject(objectName);
    Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectName);
    if (sot == null) {
      throw new ToolSecurityException('Object not found: ' + objectName);
    }
    return sot.getDescribe();
  }

  public static void validateFieldsAccessible(String objectName, List<String> fields) {
    Schema.DescribeSObjectResult objDescribe = describeObject(objectName);
    Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();

    List<String> deniedFields = new List<String>();
    for (String fieldName : fields) {
      Schema.SObjectField sField = fieldMap.get(fieldName.toLowerCase());
      if (sField == null || !sField.getDescribe().isAccessible()) {
        deniedFields.add(fieldName);
      }
    }
    if (!deniedFields.isEmpty()) {
      throw new ToolSecurityException(
        'Fields not accessible on ' + objectName + ': ' + String.join(deniedFields, ', ')
      );
    }
  }

  /**
   * Validates a child relationship name on a parent object.
   * Returns the child SObject API name so callers can validate fields on it.
   */
  public static String validateRelationship(String parentObjectName, String relationshipName) {
    Schema.DescribeSObjectResult parentDescribe = describeObject(parentObjectName);
    for (Schema.ChildRelationship cr : parentDescribe.getChildRelationships()) {
      if (cr.getRelationshipName() == relationshipName) {
        String childObjectName = cr.getChildSObject().getDescribe().getName();
        validateObject(childObjectName);
        return childObjectName;
      }
    }
    throw new ToolSecurityException(
      'Invalid relationship "' + relationshipName + '" on ' + parentObjectName
    );
  }

  public class ToolSecurityException extends Exception {}
}
