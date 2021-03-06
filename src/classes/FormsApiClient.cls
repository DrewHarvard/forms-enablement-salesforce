/**
 * Client to the Forms API Service that sits in front of CHIPS. Serlialises instances of the Form
 * class to JSON and sends them with a PDF file in a multi-part HTTP request.
 *
 * Forms API Services available:
 * - requestBarcode;
 * - sendForm;
 *
 * Author: eliot.stock@methods.co.uk
 *
 * Update 11/04/2016
 * Author: antonio.bravo@gollico.co.uk
 */
public with sharing class FormsApiClient {

    // The multipart boundary can be any old string that's unlikely to exist in the parts
    // themselves. This is a random sequence of bytes.
    private String BOUNDARY = 'webkitformboundaryAxBAy4YrqprBzdWk';

    private String SUBMISSION_ENDPOINT = '/submission';
    private String BARCODE_ENDPOINT = '/barcode';
    private String PRESENTERAPI = '/presenterauth';

    //Added for log purpose
    public static Integer numberOfTimeCalled {get; set;} 

    /**
    * Request Barcode from FormsAPI
    */
    public HttpResponse requestBarcode(Transaction__c tx) {

        //  Don't forget to add a Remote Site record for the server as well as the custom setting
        //  record.
        Forms_API_Service__c connection = getConnection();

        String log = '<br/>-----------------------------------------------------------------------------------';
        log += '<br/> Integration Date Time: ' + System.now();
        log += '<br/> Transaction Id: ' + tx.Id;
        log += '<br/> Barcode: ' + tx.Barcode__c;
        log += '<br/> Company Number: ' + tx.CompanyNumber__c;
        log += '<br/> Doc Type: ' + tx.Transaction_Type__c;
        log += '<br/> Integration Requesting Barcode Initiated';
        log += '<br/>-----------------------------------------------------------------------------------';
        if(tx.AmendmentHistory__c == null)
            tx.AmendmentHistory__c = log;
        else
            tx.AmendmentHistory__c += log;


        FormsApiClient.numberOfTimeCalled = FormsApiClient.numberOfTimeCalled == null ?  1 : FormsApiClient.numberOfTimeCalled+ 1;

        // Create Http request
        HttpRequest request = new HttpRequest();

        request.setEndpoint(connection.URL__c + BARCODE_ENDPOINT);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', '*/*');
        request.setHeader('Authorization', 'Basic ' + getAuthentication(connection));

        // Get request body
        String requestBody = getBarcodeBody();
        request.setTimeout(120000);
        request.setBody(requestBody);

        // Debug request
        System.debug(LoggingLevel.INFO, 'Request header: ' + request);
        System.debug(LoggingLevel.INFO, 'Request body: ' + request.getBody());


        // Send the request
        Http http = new Http();
        HTTPResponse response = http.send(request);

        // Debug response
        System.debug(LoggingLevel.INFO, 'Response status code: ' + response.getStatusCode());
        System.debug(LoggingLevel.INFO, 'Response body: ' + response.getBody());

        return response;

    }

    public HttpResponse requestPresenterAPI(String presenterId, String authCode){
        //  Don't forget to add a Remote Site record for the server as well as the custom setting
        //  record.
        Forms_API_Service__c connection = getConnection();
        // Create Http request
        HttpRequest request = new HttpRequest();

        request.setEndpoint(connection.URL__c + PRESENTERAPI + '?id='+presenterId + '&auth=' +authCode);
        request.setMethod('GET');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', '*/*');
        request.setHeader('Authorization', 'Basic ' + getAuthentication(connection));
        request.setTimeout(120000);
        

        // Debug request
        System.debug(LoggingLevel.INFO, 'Request header: ' + request);
        System.debug(LoggingLevel.INFO, 'Request body: ' + request.getBody());


        // Send the request
        Http http = new Http();
        HTTPResponse response = http.send(request);

        // Debug response
        System.debug(LoggingLevel.INFO, 'Response status code: ' + response.getStatusCode());
        System.debug(LoggingLevel.INFO, 'Response body: ' + response.getBody());

        return response;

    }

    /**
    * Send a Package of forms to FormsAPI
    */
    public HTTPResponse sendForm(Transaction__c tx) {
        List<Transaction__c> txList = new List<Transaction__c>();

        //This function will receive a package
        // query and add all transaction from the package to the transactions list
        txList.add(tx);

        // Don't forget to add a Remote Site record for the server as well as the custom setting
        // record.
        Forms_API_Service__c connection = getConnection();

        String log = '<br/>-----------------------------------------------------------------------------------';
        log += '<br/> Integration Date Time: ' + System.now();
        log += '<br/> Transaction Id: ' + tx.Id;
        log += '<br/> Barcode: ' + tx.Barcode__c;
        log += '<br/> Company Number: ' + tx.CompanyNumber__c;
        log += '<br/> Doc Type: ' + tx.Transaction_Type__c;
        log += '<br/> Integration Sending Form Initiated';
        log += '<br/>-----------------------------------------------------------------------------------';
        if(tx.AmendmentHistory__c == null)
            tx.AmendmentHistory__c = log;
        else
            tx.AmendmentHistory__c += log;

        FormsApiClient.numberOfTimeCalled = FormsApiClient.numberOfTimeCalled == null ?  1 : FormsApiClient.numberOfTimeCalled+ 1;

        // Create Http request
        HttpRequest request = new HttpRequest();

        request.setEndpoint(connection.URL__c + SUBMISSION_ENDPOINT);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'multipart/form-data; boundary=' + BOUNDARY);
        request.setHeader('Accept', '*/*');
        request.setHeader('Authorization', 'Basic ' + getAuthentication(connection));
        request.setTimeout(120000);

        // Get request body
        String requestBody = getBody(txList);
        request.setBody(requestBody);

        // Debug request
        System.debug(LoggingLevel.INFO, 'Request header: ' + request);
        System.debug(LoggingLevel.INFO, 'Request body: ' + request.getBody());


        // Send the request
        Http http = new Http();
        HTTPResponse response = http.send(request);

        // Debug response
        System.debug(LoggingLevel.INFO, 'Response status code: ' + response.getStatusCode());
        System.debug(LoggingLevel.INFO, 'Response body: ' + response.getBody());

        return response;
    }



    // SendForm is a multipart/form-data
    // Put parts together separate with boundary. And finish with one last boundary.
    // Note -- is part of separator
    public string getBody(List<Transaction__c> txList) {
        Integer txNumber = 0;
        String requestBody = '';


        // create a form-data for each form
        for (Transaction__c tx : txList) {
            txNumber ++;
            requestBody += getJsonPartHeader('form' + txNumber) + getJsonPartBody(tx) + '\n';
            requestBody += '\n';
        }

        // Packagemetada part
        requestBody += getJsonPartHeader('packagemetadata') + getJsonPackage(txList[0].SubmissionId__c, txNumber, txList[0].AccountNumber__c, 
            txList[0].AccountAuthorisationCode__c) + '\n';

        // Finish with one last boundary
        requestBody += '\n' + '--' + BOUNDARY + '--' + '\n';

        return requestBody;
    }

    // Aux functions to create JSON
    public string getJsonPartHeader(String name) {
        String jsonPartHeader = '--' + BOUNDARY + '\n';
        jsonPartHeader       += 'Content-Disposition: form-data; name="' + name + '"\n';
        jsonPartHeader       += '\n';

        return jsonPartHeader;
    }

    public string getJsonPackage(String packageId, Integer count, String presenterId, String presenterAuth) {
        String jsonPackage = '{ "packageIdentifier": "' + packageId + '","count": ' + count;
        if (presenterId != null) jsonPackage = jsonPackage + ',"presenterId": "' + presenterId + '"';
        if (presenterAuth != null) jsonPackage = jsonPackage + ',"presenterAuth": "' + presenterAuth + '"';
        jsonPackage = jsonPackage + ' }';
         return jsonPackage;
    }


    public string getJsonPartBody(Transaction__c tx) {
        // Hex is the simplest encoding of binary PDF data in a string. Jersey may be happier with
        // Base 64 though. We don't have anywhere to specify which encoding we're using in the part
        // header, so the API request handler simply needs to know.
        // String pdfBody = EncodingUtil.base64Encode(att.Body);

        //e.g. JSONBody
        //{
        //    "metadata": {
        //        "type": "DS01",
        //        "packageindex": "1",
        //        "version": null,
        //        "submissionnumber": "038-496948"
        //    },
        //    "formdata": {
        //        "filingDetails": {
        //            "barcode": "X53D3R3V",
        //            "receiptDate": "2016-03-23"
        //        },
        //        "corporateBody": {
        //            "incorporationNumber": "08906750",
        //            "corporateBodyName": "Methods Digital Limited"
        //        }
        //    },
        //    "attachments": [
        //        {
        //            "mimetype": "application/pdf",
        //            "category": "FORM IMAGE PDF",
        //            "data": pdfBody
        //        }
        //    ]
        //}

        //call TransactionSerialiser to get JSON
        String jsonPartBody = TransactionSerialiser.transactionToJSON(tx);
        if (tx.Form_Name__c.contains('DS01')) {
            jsonPartBody = jsonPartBody.remove('"subdividedClasses" : null,');
            jsonPartBody = jsonPartBody.remove('"statementOfCapital" : null,');
            jsonPartBody = jsonPartBody.remove('"shares" : null,');
            jsonPartBody = jsonPartBody.remove('"shareAssignments" : null,');
            jsonPartBody = jsonPartBody.remove('"redeemedClasses" : null,');
            jsonPartBody = jsonPartBody.remove('"reconvertedClasses" : null,');
            jsonPartBody = jsonPartBody.remove('"consolidatedClasses" : null');
            jsonPartBody = jsonPartBody.remove('"detailsOfVariationOfRights" : null,');
        }
        if(tx.Form_Name__c.contains('DS02'))
        {//\n
            jsonPartBody = jsonPartBody.remove('"payment" : {');
            jsonPartBody = jsonPartBody.remove('"referenceNumber" : null,');
            jsonPartBody = jsonPartBody.remove('"paymentMethod" : null,');
            jsonPartBody = jsonPartBody.remove('"accountNumber" : null\n      },');
            jsonPartBody = jsonPartBody.remove('"subdividedClasses" : null,');
            jsonPartBody = jsonPartBody.remove('"statementOfCapital" : null,');
            jsonPartBody = jsonPartBody.remove('"shares" : null,');
            jsonPartBody = jsonPartBody.remove('"shareAssignments" : null,');
            jsonPartBody = jsonPartBody.remove('"redeemedClasses" : null,');
            jsonPartBody = jsonPartBody.remove('"reconvertedClasses" : null,');
            jsonPartBody = jsonPartBody.remove('"consolidatedClasses" : null');
            jsonPartBody = jsonPartBody.remove('"detailsOfVariationOfRights" : null,');
            jsonPartBody = jsonPartBody.remove('"officers" : {');
            jsonPartBody = jsonPartBody.remove('"officer" : [ ]\n      },');
        }
        jsonPartBody = jsonPartBody.replace('sNumber', 'number');
        jsonPartBody = jsonPartBody.replace('classValue', 'class');
        jsonPartBody = jsonPartBody.remove('"officers" : null,');
        system.debug(LoggingLevel.ERROR, 'Json ready to be sent:' + jsonPartBody);
        return jsonPartBody;
    }

    //Barcode body
    public String getBarcodeBody() {
        String month;

        Date d = System.today();


        if (d.month() < 10)
            month = '0' + String.valueOf(d.month());
        else
            month = String.valueOf(d.month());


        //e.g. '20160413';
        String dateString = String.valueOf(d.year()) + month + String.valueOf(d.day());

        return '{"datereceived":' + dateString + '}';
    }

    // Aux for Authentication
    public String getAuthentication(Forms_API_Service__c connection) {
        // Basic HTTP auth header for Forms API Service on AWS.
        String usernamePasswordPair = connection.Username__c + ':' + connection.Password__c;
        String authValue = EncodingUtil.base64Encode(Blob.valueOf(usernamePasswordPair));

        return authValue;
    }


    // Look for a custom setting record with the URL, username and password for the server.
    public static Forms_API_Service__c getConnection() {
        List<Forms_API_Service__c> connections = Forms_API_Service__c.getAll().values();

        // Return the first active one found.
        for (Forms_API_Service__c connection : connections) {
            if (connection.Active__c) {
                return connection;
            }
        }

        // Unit tests should not rely on custom settings records.
        if (Test.isRunningTest()) {
            Forms_API_Service__c c = new Forms_API_Service__c(URL__c = 'http://example.com',
                    Username__c = 'unitTestUsername', Password__c = 'unitTestPassword',
                    Active__c = true);
            return c;
        }

        System.debug(LoggingLevel.ERROR, 'No active Forms API Service records exist under Custom'
                     + ' Settings. Can\'t connect to the Forms API Service.');
        return null;
    }
}