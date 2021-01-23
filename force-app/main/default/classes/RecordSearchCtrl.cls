global with sharing class RecordSearchCtrl {
    public String searchText {get ; set;}
    public List<SearchResult> results {get; set;}
    private List<SearchResult> totalResults;
    public Boolean isClickSearch {get; set;}
    private Integer pageSize;
    public String selectedPageSize {get; set;} 
    private Integer offset;
    public Integer totalRecords {get; set;}
    public Integer pageNumber {get; set;}
    public Integer totalPage {get; set;}
    public List<SelectOption> availablePageSizes {get; private set;}
    public Set<String> tableHeaders {get; set;}
    private Map<String, Schema.SObjectType> globalDescribe;

    public RecordSearchCtrl() {
        this.searchText = 'united';   // test search term
        this.results = new List<SearchResult>();
        this.totalResults = new List<SearchResult>();
        this.isClickSearch = false;
        this.pageSize = 5;
        this.selectedPageSize = '5';
        this.offset = 0;
        this.totalRecords = 0;
        this.pageNumber = 1;
        this.totalPage = 0;
        this.availablePageSizes = new List<SelectOption>{
            new SelectOption('5', '5'),
            new SelectOption('10', '10'),
            new SelectOption('15', '15')
        };
        this.tableHeaders = new Set<String>{
            'Record Name', 'Record Type', 'Click To Open', 'Counter', 'Click To Update Counter'
        };
        this.globalDescribe = Schema.getGlobalDescribe();
    }
     
    public PageReference search() {
        // Validation
        Boolean isError = false;
        if (String.isBlank(this.searchText) || this.searchText.trim().length() == 1) {
            isError = true;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Search term must be two or more characters'));
        }
        if (isError) return null;

        // Clear previous search results;
        this.totalResults.clear();
        this.results.clear();
        this.offset = 0;
        this.pageNumber = 1;
        this.totalPage = 0;
        this.isClickSearch = true;

        // Search new data
        try {
            List<String> fields = new List<String> {'Name', 'RecordType', 'Id', 'Counter__c'};
            String searchTerm = String.escapeSingleQuotes(this.searchText) + '*';
            List<List<SObject>> searchList = [FIND :searchTerm IN NAME FIELDS RETURNING Account (Id, Name, Counter__c ORDER BY CreatedDate), Contact (Id, Name, Counter__c ORDER BY CreatedDate)];
            
            for (List<SObject> sObjects :  searchList) {
                for (SObject so : sObjects) {
                    String recordType = (String) so.getSObjectType().getDescribe().getName();
                    SearchResult sr = new SearchResult();   
                    sr.recordId = (String) so.get('Id');
                    sr.recordType = recordType;
                    Map<String, Schema.SObjectField> sofm = this.globalDescribe.get(recordType).getDescribe().fields.getMap();

                    Boolean showAddCounter = false;
                    // Build searchResult fields displayed
                    for (String field : fields) {
                        FieldResult fr = new FieldResult();
                        fr.fieldName = field;
                        if (field == 'RecordType') {
                            fr.isAccessible = true;
                            fr.fieldValue = recordType;
                            sr.fieldResults.add(fr);        
                        } else {
                            fr.isAccessible = sofm.get(field).getDescribe().isAccessible();
                            fr.isUpdateable = sofm.get(field).getDescribe().isUpdateable();
                            if (fr.isAccessible) {
                                fr.fieldValue = getFieldValue(so, field, sofm);
                            }
                            sr.fieldResults.add(fr);
                            if (fr.fieldName == 'Counter__c') {
                                FieldResult cfr = new FieldResult();
                                cfr.isAccessible = fr.isAccessible;
                                cfr.isUpdateable = fr.isUpdateable;
                                cfr.fieldName = 'addCounter';
                                cfr.fieldValue = 'Increment Counter';
                                sr.fieldResults.add(cfr);
                            }
                        }
                    }
                    this.totalResults.add(sr);
                }
            }
            this.totalRecords = this.totalResults.size();
            if (this.totalRecords > 0) {
                this.totalPage = (Integer) Math.ceil(Double.valueOf(this.totalRecords) / Double.valueOf(this.pageSize));
                return this.buildDisplayRecords();
            } else {
                return null;
            }
        } catch (Exception ex) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, ex.getMessage()));
            return null;
        }
    }
    
    public Pagereference buildDisplayRecords() {
        this.results.clear();
        Integer lastIndex = this.totalRecords <= (this.pageNumber * this.pageSize) ? this.totalRecords : (this.pageNumber * this.pageSize);
        for (Integer i = this.offset; i < lastIndex; i++) {
            this.results.add(this.totalResults[i]);
        }
        return null;
    }

    private String getFieldValue(sObject so, String field,  Map<String, Schema.SObjectField> sofm) {
        String returnVal = null;
        Schema.DisplayType displayType = sofm.get(field).getDescribe().getType();
        if (displayType == Schema.DisplayType.INTEGER || displayType == Schema.DisplayType.LONG || displayType == Schema.DisplayType.DOUBLE) {
            returnVal = so.get(field) == null ? '0' : String.valueOf(so.get(field));
        } else {
            returnVal = so.get(field) == null ? null : (String) so.get(field);
        }
        return returnVal;
    }

    public Pagereference onFirstPage() {
        this.pageNumber = 1;
        this.offset = 0;
        return this.buildDisplayRecords();
    }

    public Pagereference onPreviousPage() {
        this.pageNumber--;
        this.offset -= this.pageSize;
        return this.buildDisplayRecords();     
    }

    public Pagereference onNextPage() {
        this.pageNumber++;
        this.offset += this.pageSize;
        return this.buildDisplayRecords();
    }

    public Pagereference onLastPage() {
        this.pageNumber = this.totalPage;
        this.offset = this.totalRecords - (Math.mod(this.totalRecords, this.pageSize));
        return this.buildDisplayRecords();
    }

    public Pagereference onChangePageSize() {
        this.pageSize = Integer.valueOf(this.selectedPageSize);
        return search();
    }

    @RemoteAction 
    global static Decimal increaseCounter(String recordId, String recordType) {
        Decimal newCounter = null;
        try {
            String queryTemplate = 'SELECT Id, Counter__c FROM {0} WHERE Id = {1}';
            String query = String.format(queryTemplate, new List<String>{
                String.escapeSingleQuotes(recordType),
                '\'' + String.escapeSingleQuotes(recordId) + '\''
            });
            List<SObject> records = Database.query(query);
            if (!records.isEmpty()) {
                SObject record = records[0];
                Decimal currentCounter = record.get('Counter__c') == null ? 0 : (Decimal) record.get('Counter__c');
                newCounter = currentCounter + 1;
                record.put('Counter__c', newCounter);
                
                // Update records
                SObjectAccessDecision securityDecision = Security.stripInaccessible(AccessType.UPDATABLE, records);
                update securityDecision.getRecords();
            }
        } catch (Exception ex) {
            System.debug('@@@ increaseCounter.ex= ' + ex.getMessage());
        }
        return newCounter;
    }
    
    class SearchResult {
        public String recordId {get; set;}
        public String recordType {get; set;}
        public List<FieldResult> fieldResults {get; set;}
        SearchResult() {
            this.recordId = null;
            this.recordType = null;
            this.fieldResults = new List<FieldResult>();
        }
    }

    class FieldResult {
        public Boolean isAccessible {get; set;}
        public Boolean isUpdateable {get; set;}
        public String fieldName {get; set;}
        public String fieldValue {get; set;}
        FieldResult() {
            this.isAccessible = false;
            this.isUpdateable = false;
            this.fieldName = null;
            this.fieldValue = null;
        }
    }
}