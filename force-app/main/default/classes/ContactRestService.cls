@RestResource(urlMapping='/ContactService/v1')
global with sharing class ContactRestService {
    @HttpPatch
    global static void updateContactFields() {
        RestRequest request = RestContext.request;
        RestResponse response = RestContext.response;
        response.addHeader('Content-Type', 'application/json');

        try {
            List<Object> inputRecords = (List<Object>)JSON.deserializeUntyped(request.requestbody.tostring());
            if (inputRecords.isEmpty()) {
                response.statusCode = 200;
                ResponseBody content = new ResponseBody(true, 'No record to update');
                response.responseBody = Blob.valueOf(JSON.serialize(content));
                return;
            }

            List<ApiResult> apiResults = new List<ApiResult>();
            List<Contact> contactToUpdates = new List<Contact>();
            for (Object inputRecord : inputRecords) {
                Map<String, Object> params = (Map<String, Object>) inputRecord;
                Contact ct = new Contact();
                try {
                    for (String fieldName : params.keySet()) {
                        ct.put(fieldName, params.get(fieldName));
                    }
                    contactToUpdates.add(ct);
                } catch (Exception ex) {
                    ApiResult result = new ApiResult(false, ex.getMessage(), ct.get('Id') == null ? null : (String) ct.get('Id'));
                    apiResults.add(result);
                }
            }

            if (!contactToUpdates.isEmpty()) {
                SObjectAccessDecision securityDecision = Security.stripInaccessible(AccessType.UPDATABLE, contactToUpdates);
                List<Database.SaveResult> updateResults = Database.update(securityDecision.getRecords(), false);
                for (Database.SaveResult updateResult : updateResults) {
                    ApiResult result;
                    if (updateResult.isSuccess()) {
                        result = new ApiResult(true, 'Update successfully', updateResult.getId());
                    } else {
                        result = new ApiResult(false, handleErrors(updateResult.getErrors()), updateResult.getId());
                    }
                    apiResults.add(result);
                }
            }
            response.statusCode = 200;
            ResponseBody content = new ResponseBody(true, null);
            content.records = apiResults;
            response.responseBody = Blob.valueOf(JSON.serialize(content));

        } catch (Exception ex) {
            response.statusCode = 500;
            ResponseBody content = new ResponseBody(false, ex.getMessage() + ', location: ' + ex.getStackTraceString());
            response.responseBody = Blob.valueOf(JSON.serialize(content));
        }
    }

    private static String handleErrors(List<Database.Error> errors) {
        String returnError = '';
        for (Database.Error error : errors) {
            returnError += 'Error code: ' + error.getStatusCode() + ', error message: ' + error.getMessage() + ', error fields: ' + error.getFields() + '\n';
        }
        return returnError.removeEnd('\n');
    }

    class ResponseBody {
        Boolean isSuccess;
        String message;
        List<ApiResult> records;
        public ResponseBody(Boolean isSuccess, String message) {
            this.isSuccess = isSuccess;
            this.message = message;
            this.records = new List<ApiResult>();
        }
    }

    class ApiResult {
        Boolean isSuccess;
        String message;
        String sObjectId;
        public ApiResult(Boolean isSuccess, String message, String sObjectId) {
            this.isSuccess = isSuccess;
            this.message = message;
            this.sObjectId = sObjectId;
        }
    }
}