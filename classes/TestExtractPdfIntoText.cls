@isTest
public class TestExtractPdfIntoText {

    // Mock HTTP response to simulate OCR API
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"ParsedResults":[{"ParsedText":"Sample extracted text from PDF"}]}');
            return res;
        }
    }

    @isTest
    static void testExtractTextFromPdf() {
        // Step 1: Set the HTTP callout mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        // Step 2: Create a test Case
        Case testCase = new Case(
            Subject = 'Test OCR Case',
            Status = 'New'
        );
        insert testCase;

        // Step 3: Create a dummy PDF and insert ContentVersion
        Blob pdfBlob = Blob.valueOf('%PDF-1.4 Test content for PDF file');
        ContentVersion cv = new ContentVersion(
            Title = 'TestPDF',
            PathOnClient = 'TestPDF.pdf',
            VersionData = pdfBlob
        );
        insert cv;

        // Step 4: Publish the ContentVersion (required to link to a Case)
        ContentVersion insertedCV = [
            SELECT Id, ContentDocumentId 
            FROM ContentVersion 
            WHERE Id = :cv.Id 
            LIMIT 1
        ];

        // Step 5: Link the document to the Case
        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = testCase.Id,
            ContentDocumentId = insertedCV.ContentDocumentId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;

        // Step 6: Build request
        ExtractPdfIntoText.Request req = new ExtractPdfIntoText.Request();
        req.caseId = testCase.Id;

        // Step 7: Invoke the method
        Test.startTest();
        List<ExtractPdfIntoText.Response> results = ExtractPdfIntoText.extractTextFromPdfs(new List<ExtractPdfIntoText.Request>{ req });
        Test.stopTest();

        // Step 8: Assertions to validate outcome
        System.assertEquals(1, results.size(), 'Should return one response');
        System.assert(
            results[0].extractedText.contains('Sample extracted text from PDF'),
            'Extracted text should match mocked OCR output'
        );
    }
}