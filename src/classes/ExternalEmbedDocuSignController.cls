/*
Name:  ExternalEmbedDocuSignController.cls
Copyright © 2016  Methods Digital
======================================================
======================================================
Purpose:
-------

Controller class for the Visualforce Page: ExternalEmbedDocuSign

======================================================
======================================================
History
------- 
Ver. Author        Date        Detail
1.0  Sylvain Picory&    2016-07-05  Initial development.
*/
public class ExternalEmbedDocuSignController extends TransactionStepControllerBase {

	public String externalURL {get; set;}

	public ExternalEmbedDocuSignController(){
		super();
		initialiseStep();
	}

	public void initialiseStep() {
	}

    public PageReference checkSignature(){

    if(ApexPages.currentPage().getParameters().containsKey('event') && !String.isBlank(ApexPages.currentPage().getParameters().get('event'))) {
            
        PageReference pg = new PageReference('/DigitalSignature');
        pg.getParameters().put('c', SecurityManager.encryptText(submissionMgr.submission.Id+AppConstants.ID_DELIM_CHAR+transactionMgr.currentStep.Id+AppConstants.ID_DELIM_CHAR+String.valueOf(DateTime.now().getTime())));
        pg.setRedirect(true);

        return pg;
        // Transaction has been declined
        }

        return null;
    }

	public PageReference initSiging(){

        PageReference pr = checkSignature();
        
        if(pr != null)
            return pr;

        if (!ApexPages.currentPage().getParameters().containsKey('c') || 
            String.isBlank(ApexPages.currentPage().getParameters().get('c'))) return null;

        String paramInput = ApexPages.currentPage().getParameters().get('c');

        if(paramInput.contains(' '))
        {
            paramInput = paramInput.replace(' ', '+');

            ApexPages.currentPage().getParameters().put('c',paramInput);

            ApexPages.currentPage().setRedirect(true);

            return ApexPages.currentPage();
        }

        

        DocuSignSetting__c dsSetting = getDocuSignSettings();

        //Build the unique document for the envelope
        Blob pdfBlob;
        PageReference pageRef = new PageReference('/apex/PDFGeneration');
        pageRef.getParameters().put('id',submissionMgr.submission.Id);
        if(Test.IsRunningTest())
            pdfBlob = Blob.valueOf('This is a test');
        else
            pdfBlob = pageRef.getContent();  

        DocuSignAPI.Document doc = DocusignLibrary.getDocument(1, EncodingUtil.base64Encode(pdfBlob), submissionMgr.submission.Form_Name__c + '_'+ submissionMgr.submission.CompanyName__c + '_'+ getDate(), 'pdf');

        DocuSignAPI.CustomField custF1 = DocusignLibrary.getCustomField( 'DSFSSourceObjectId', submissionMgr.submission.Id + '~Transaction__c', 'Text');
        DocuSignAPI.CustomField custF2 = DocusignLibrary.getCustomField( 'OfficerSigner1', submissionMgr.submission.Officers__r[0].Id + '~Officer__c', 'Text');

        String emailBlurb = '<h1 class="page-title-style-email">Application to close'+' '+submissionMgr.submission.CompanyName__c+' '+'</h1><p>An application to close'+' '+submissionMgr.submission.CompanyName__c+' '+'needs your approval before it can be submitted to Companies House for processing. </p> <h2 class="second-level-heading">What to do next</h2> <p class="paragraphs-regular"> Please ensure that you have read and understood your responsibilities as a director in this process before approving the application. Guidance on the process of voluntarily closing a company can be found on the Companies House website. Once the application has been submitted you will receive an email containing a link to the submitted application. It is your responsibility as a director to ensure that copies of the application have been sent to all notifiable parties within 7 days of submitting the completed application. This includes <ul> <li>Creditors</li> <li>Employees</li> <li>Shareholders</li> <li>Pension managers or trustees</li> </ul> </p> <p class="paragraphs-regular"> Note: Please check the guidance notes which contain a full list of those who must be notified. </p> <p> <b>Failure to notify interested parties is an offence. It is advisable to obtain and retain some proof of delivery or posting of copies to notifiable parties.</b> </p> <p> If the application has not been signed by all required directors by'+ ' '+submissionMgr.submission.ExpiryDate__c+' '+ ', the application will be automatically cancelled. </p>';        
        DocuSignAPI.Envelope env = DocusignLibrary.getEnvelope(dsSetting.AccountId__c, submissionMgr.submission.Form_Name__c + ' - application for ' + submissionMgr.submission.CompanyName__c,  emailBlurb);
        
        //Init size of each collection of the envelope
        env = DocusignLibrary.initDocs(env, 1);
        env = DocusignLibrary.initCustomFields(env, 2);

        env = DocusignLibrary.initRecipients(env, submissionMgr.submission.Officers__r.size());

        env = DocusignLibrary.initTabs(env, submissionMgr.submission.Officers__r.size() * 2);
        env = DocusignLibrary.addDocs(env, doc);

        env = DocusignLibrary.addCustomFields(env, custF1);
        env = DocusignLibrary.addCustomFields(env, custF2);

        DocuSignAPI.Notification notif = DocusignLibrary.getNotification(true);

        env = DocusignLibrary.addNotification(env, notif);

        for(Integer i = 0; i < submissionMgr.submission.Officers__r.size(); i++)
        {
            Officer__c off = submissionMgr.submission.Officers__r[i];
            if(off.isSignatory__c)
            {
                DocuSignAPI.RecipientCaptiveInfo capInfo;

                if(off.IsPresenter__c)
                {
                    capInfo = DocusignLibrary.getCaptiveInfo(off.Email__c);
                }

                String recName = (off.isCorporateDirector__c == true ? off.AuthorizedSigner__c : (off.isPowerOfAttorney__c == true ? off.AuthorizedSigner__c : convertName(off.Name)));

                DocuSignAPI.Recipient rec = DocusignLibrary.getRecipient(Integer.valueOf(off.RecipientId__c), 'Signer', 1, off.Email__c, recName, capInfo, false);

                DocuSignAPI.AnchorTab anch = DocusignLibrary.getAnchorTab('/s' + Integer.valueOf(off.RecipientId__c) + '/');

                DocuSignAPI.Tab tabE = DocusignLibrary.getTab('SignHere', Integer.valueOf(off.RecipientId__c), 1, anch);

                DocuSignAPI.AnchorTab anch2 = DocusignLibrary.getAnchorTab('/sd' + Integer.valueOf(off.RecipientId__c) + '/');

                DocuSignAPI.Tab tabE2 = DocusignLibrary.getTab('DateSigned', Integer.valueOf(off.RecipientId__c), 1, anch2);

                env = DocusignLibrary.addRecipients(env, rec);

                env = DocusignLibrary.addTabs(env, tabE);
                env = DocusignLibrary.addTabs(env, tabE2);
                
            }
        }

        //Build httpHeader
        String auth = DocusignLibrary.buildAuthString( dsSetting.Username__c, dsSetting.Password__c, dsSetting.IntegratorKey__c);
        Map<String, String> httpHeader = DocusignLibrary.buildHTTPHeaders(auth);

        String baseURL = Site.getBaseUrl() + ApexPages.currentPage().getUrl().substringAfter('/apex').substringBefore('?');

        if(baseURL == '')
        {   
            baseURL = ApexPages.currentPage().getHeaders().get('Host') + ApexPages.currentPage().getUrl();
            
        }
        //Here page URL contains Apex/Payment
        baseURL = baseURL.substringBefore('?') + '?c=' + SecurityManager.encryptText(submissionMgr.submission.Id+AppConstants.ID_DELIM_CHAR+transactionMgr.currentStep.Id+AppConstants.ID_DELIM_CHAR+String.valueOf(DateTime.now().getTime())) ;
		externalURL = DocusignLibrary.sendEnvelope(dsSetting.URL__c, httpHeader, env, baseURL);

        return null;
	}

	// API is returning last name + first Name
    // This function set name in the correct order
    public String convertName(String name) {
        String firstName;
        String lastName;

        firstName = name.substringAfter(',') + ' ';
        
        lastName = name.substringBefore(',');
        lastName = lastName.toLowerCase();
        lastName = lastName.capitalize();

        return firstName + lastName;
    }

    public String getDate(){
        Date d = date.today();
        String day   = d.day()   > 9 ? string.valueOf(d.day())   : '0' + string.valueOf(d.day());
        String month = d.month() > 9 ? string.valueOf(d.month()) : '0' + string.valueOf(d.month());

        return day + month + d.year();
    }

    // Look for a custom setting record with the URL, username and password for the DocuSign server.
    public static DocuSignSetting__c getDocuSignSettings() {
        List<DocuSignSetting__c> dsSettingsList = DocuSignSetting__c.getAll().values();
        
        // Return the first active one found.
        for (DocuSignSetting__c dsSett : dsSettingsList) {
            if (dsSett.Active__c) {
                return dsSett;
            }
        }
        
        // Unit tests should not rely on custom settings records.
        if (Test.isRunningTest()) {
            String dsPrefix = dsfs__DocuSign_Status__c.sobjecttype.getDescribe().getKeyPrefix();

            DocuSignSetting__c dsSettTest = new DocuSignSetting__c(Name = 'DocuSign Test Settings',
                                                    Username__c         = 'unitTestUsername', 
                                                    Password__c         = 'unitTestPassword',
                                                    AccountId__c        = 'unitTestAccountId',
                                                    IntegratorKey__c    = 'unitTestIntegratorKey',
                                                    URL__c              = 'unitTestURL',
                                                    RecordIdPrefix__c   = dsPrefix,
                                                    Active__c           = true);
            return dsSettTest;
        }
        
        System.debug(LoggingLevel.ERROR, 'No active DocuSignSetting records exist under Custom'
                     + ' Settings. Can\'t connect to DocuSign.');
        return null;
    }
}