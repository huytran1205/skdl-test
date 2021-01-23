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
        this.isClickSearch = true;

        // Search new data
        try {
            String searchTerm = String.escapeSingleQuotes(this.searchText) + '*';
            List<List<SObject>> searchList = [FIND :searchTerm IN NAME FIELDS RETURNING Account (Id, Name, Counter__c ORDER BY CreatedDate), Contact (Id, Name, Counter__c ORDER BY CreatedDate)];
            for (List<SObject> sObjects :  searchList) {
                for (SObject so : sObjects) {
                    SearchResult sr = new SearchResult();     
                    sr.recordId = (String) so.get('Id');
                    sr.recordName = (String) so.get('Name');
                    sr.recordType = (String) so.getSObjectType().getDescribe().getName();
                    sr.recordCounter = so.get('Counter__c') == null  ? 0 : (Decimal) so.get('Counter__c');
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
        public String recordName {get; set;}
        public String recordType {get; set;}
        public Decimal recordCounter {get; set;}
        SearchResult() {
            this.recordId = null;
            this.recordName = null;
            this.recordType = null;
            this.recordCounter = null;
        }
    }
}