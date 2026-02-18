public class AgentUnitOfWork {
  private List<SObject> recordsToInsert = new List<SObject>();
  private List<SObject> recordsToUpdate = new List<SObject>();
  private List<SObject> recordsToDelete = new List<SObject>();

  public void registerNew(SObject record) {
    recordsToInsert.add(record);
  }

  public void registerNew(List<SObject> records) {
    recordsToInsert.addAll(records);
  }

  public void registerInsert(SObject record) {
    recordsToInsert.add(record);
  }

  public void registerDirty(SObject record) {
    recordsToUpdate.add(record);
  }

  public void registerDirty(List<SObject> records) {
    recordsToUpdate.addAll(records);
  }

  public void registerUpdate(SObject record) {
    recordsToUpdate.add(record);
  }

  public void registerDeleted(SObject record) {
    recordsToDelete.add(record);
  }

  public void registerDeleted(List<SObject> records) {
    recordsToDelete.addAll(records);
  }

  public void registerDelete(SObject record) {
    recordsToDelete.add(record);
  }

  private List<String> dmlErrors = new List<String>();

  public void commitWork() {
    if (!recordsToInsert.isEmpty()) {
      Database.SaveResult[] insertResults = Database.insert(recordsToInsert, false);
      collectErrors(insertResults, 'insert');
    }
    if (!recordsToUpdate.isEmpty()) {
      Database.SaveResult[] updateResults = Database.update(recordsToUpdate, false);
      collectErrors(updateResults, 'update');
    }
    if (!recordsToDelete.isEmpty()) {
      Database.DeleteResult[] deleteResults = Database.delete(recordsToDelete, false);
      collectDeleteErrors(deleteResults);
    }
  }

  private void collectErrors(Database.SaveResult[] results, String operation) {
    for (Integer i = 0; i < results.size(); i++) {
      if (!results[i].isSuccess()) {
        Database.Error error = results[i].getErrors()[0];
        String recordId = recordsToInsert.size() > i && operation == 'insert'
          ? String.valueOf(recordsToInsert[i].Id)
          : (recordsToUpdate.size() > i && operation == 'update' ? String.valueOf(recordsToUpdate[i].Id) : 'unknown');
        dmlErrors.add(operation.capitalize() + ' failed for record ' + recordId + ': ' + error.getMessage());
      }
    }
  }

  private void collectDeleteErrors(Database.DeleteResult[] results) {
    for (Integer i = 0; i < results.size(); i++) {
      if (!results[i].isSuccess()) {
        Database.Error error = results[i].getErrors()[0];
        String recordId = recordsToDelete.size() > i ? String.valueOf(recordsToDelete[i].Id) : 'unknown';
        dmlErrors.add('Delete failed for record ' + recordId + ': ' + error.getMessage());
      }
    }
  }

  public List<String> getDmlErrors() {
    return dmlErrors;
  }

  public Boolean isEmpty() {
    return recordsToInsert.isEmpty() &&
           recordsToUpdate.isEmpty() &&
           recordsToDelete.isEmpty();
  }

  public List<SObject> getInsertedRecords() {
    return recordsToInsert;
  }

  public List<SObject> getUpdatedRecords() {
    return recordsToUpdate;
  }

  public List<SObject> getDeletedRecords() {
    return recordsToDelete;
  }

  /**
   * Returns a summary of record IDs after commit, grouped by SObject type.
   * Example: "Created Account IDs: 001... | Created Contact IDs: 003... | Updated Case IDs: 500..."
   */
  public String getCommitSummary() {
    List<String> summaries = new List<String>();

    addTypedSummary(summaries, recordsToInsert, 'Created');
    addTypedSummary(summaries, recordsToUpdate, 'Updated');
    addTypedSummary(summaries, recordsToDelete, 'Deleted');

    if (!dmlErrors.isEmpty()) {
      summaries.addAll(dmlErrors);
    }

    return String.join(summaries, ' | ');
  }

  private void addTypedSummary(List<String> summaries, List<SObject> records, String verb) {
    if (records.isEmpty()) {
      return;
    }
    Map<String, List<String>> idsByType = new Map<String, List<String>>();
    for (SObject record : records) {
      if (record.Id != null) {
        String typeName = String.valueOf(record.getSObjectType());
        if (!idsByType.containsKey(typeName)) {
          idsByType.put(typeName, new List<String>());
        }
        idsByType.get(typeName).add(String.valueOf(record.Id));
      }
    }
    for (String typeName : idsByType.keySet()) {
      summaries.add(verb + ' ' + typeName + ' IDs: ' + String.join(idsByType.get(typeName), ', '));
    }
  }
}
