public with sharing class ExtractPdfIntoText {   
 
    private static final String OCR_API_KEY = 'K85081106388957';  
    private static final String OCR_ENDPOINT = 'https://api.ocr.space/parse/image';

    @InvocableMethod(label='Extraction PDFs/PNG Text'
        description='Extracts text from PDF or PNG related to Case')
    public static List<Response> extractTextFromPdfs(List<Request> requests) {
        Request input = requests[0];
        List<Response> responses = new List<Response>();
        Response output = new Response();
        responses.add(output);
        
        Map<String, String> extractedTexts = new Map<String, String>();
        
        try {
            // Step 1: Fetch ContentDocumentIds linked to the Case
            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId FROM ContentDocumentLink 
                WHERE LinkedEntityId = :input.caseId
            ];
            
            if (links.isEmpty()) {
                output.extractedText = 'Error: No documents attached to the case.';
                return responses;
            }
            
            for (ContentDocumentLink link : links) {
                // Step 2: Fetch ContentVersion (PDF or PNG file)
                ContentVersion file = [
                    SELECT Id, VersionData, Title, FileExtension 
                    FROM ContentVersion 
                    WHERE ContentDocumentId = :link.ContentDocumentId 
                    ORDER BY CreatedDate DESC 
                    LIMIT 2
                ];

                // Validate file type
                if (!isValidFileType(file.FileExtension)) {
                    output.extractedText = 'Error: Unsupported file type.';
                    return responses;
                }

                // Step 3: Convert file data to Base64 for API call
                String base64File = EncodingUtil.base64Encode(file.VersionData);

                // Step 4: Make HTTP Callout to OCR API
                Http http = new Http();
                HttpRequest request = new HttpRequest();
                request.setEndpoint(OCR_ENDPOINT);
                request.setMethod('POST');
                request.setHeader('apikey', OCR_API_KEY);
                request.setHeader('Content-Type', 'application/x-www-form-urlencoded');

                // Determine filetype and construct request body accordingly
                String body = 'language=eng'
                            + '&isOverlayRequired=false'
                            + '&filetype=' + getFileType(file.FileExtension)
                            + '&base64Image=' + EncodingUtil.urlEncode(getFilePrefix(file.FileExtension) + base64File, 'UTF-8')
                            + '&ocrengine=2'; // Use advanced OCR engine if needed
                request.setBody(body);

                // Step 5: Process the Response
                HttpResponse response = http.send(request);
                if (response.getStatusCode() == 200) {
                    Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                    List<Object> parsedResults = (List<Object>) responseBody.get('ParsedResults');
                    
                    if (parsedResults != null && !parsedResults.isEmpty()) {
                        String extractedText = '';
                        for (Object result : parsedResults) {
                            Map<String, Object> parsedResult = (Map<String, Object>) result;
                            extractedText += (String) parsedResult.get('ParsedText') + '\n';
                        }
                        extractedTexts.put(file.Title, extractedText.trim());
                    } else {
                        extractedTexts.put(file.Title, 'Error: No text extracted from the document.');
                    }
                } else {
                    extractedTexts.put(file.Title, 'Error: OCR API call failed with status ' + response.getStatus());
                }
            }
            
            // Format the output
            String finalText = 'Extracted Texts:\n';
            for (String title : extractedTexts.keySet()) {
                finalText += title + ': ' + extractedTexts.get(title) + '\n\n';
            }
            output.extractedText = finalText.trim();
        } catch (Exception e) {
            output.extractedText = 'Exception: ' + e.getMessage();
        }
        
        return responses;
    }
    
    // Helper method to validate file extension
    private static Boolean isValidFileType(String extension) {
        return extension.equalsIgnoreCase('pdf') || extension.equalsIgnoreCase('png');
    }
    
    // Helper method to determine OCR API filetype parameter
    private static String getFileType(String extension) {
        return extension.equalsIgnoreCase('pdf') ? 'pdf' : 'image';
    }
    
    // Helper method to determine the base64 prefix based on file type
    private static String getFilePrefix(String extension) {
        return extension.equalsIgnoreCase('pdf') ? 'data:application/pdf;base64,' : 'data:image/png;base64,';
    }

    public class Request {
        @InvocableVariable(required=true)
        public String caseId;
    }

    public class Response {
        @InvocableVariable
        public String extractedText;
    }
}