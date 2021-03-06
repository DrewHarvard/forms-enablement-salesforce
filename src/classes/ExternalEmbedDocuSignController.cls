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
public with sharing class ExternalEmbedDocuSignController extends TransactionStepControllerBase {

    public String externalURL {get; set;}
    public String officerTerm {get; set;}
    public String compName {get; set;}

    public ExternalEmbedDocuSignController() {
        super();
        initialiseStep();
    }

    public void initialiseStep() {
        officerTerm = submissionMgr.submission.officerTerminology__c == null ? 'Director(s)' : submissionMgr.submission.officerTerminology__c;
        officerTerm = officerTerm.replace('s', '');
        compName = submissionMgr.submission.CompanyName__c == null ? 'Default Name' : submissionMgr.submission.CompanyName__c;
    }


    public PageReference initSiging() {
        PageReference res = initialiseAction();

        if(res != null)
            return res;

        externalURL = docusignSignature(submissionMgr, transactionMgr);

        return null;
    }

    public static String docusignSignature(SubmissionManager submissionMgrParam, TransactionManager transactionMgrParam) {
        
        System.debug(LoggingLevel.INFO, 'DocuSign Logging: entered docusignSignature');
        
        SubmissionManager submissionMgr = submissionMgrParam;
        TransactionManager transactionMgr = transactionMgrParam;
        DocuSignSetting__c dsSetting = getDocuSignSettings();

        //Build the unique document for the envelope
        Blob pdfBlob;

        //Logic to generate the right PDF for DS01
        String page = 'DS01';
        String emailBlurb ='<tr><td width="100%" style="font-family: Helvetica, Arial, sans-serif;"><h1 class="email" style="font-weight: 700; font-size: 48px; line-height: 1.041666667; margin: 30px 0;">Request to close '+submissionMgr.submission.CompanyName__c+'</h1></td></tr><tr><td width="100%" style="font-family: Helvetica, Arial, sans-serif;"><p style="font-size: 19px; line-height: 1.315789474; margin: 0 0 30px 0;">A request to close '+submissionMgr.submission.CompanyName__c + ' ('+submissionMgr.submission.CompanyNumber__c+') whose registered office address is '+submissionMgr.submission.CompanyAddress1__c+' '+  submissionMgr.submission.CompanyPostCode__c+' <b>needs your approval</b> before it can be submitted to Companies House for processing. </br> </br>The request will be deleted if it\'s not approved and completed by '+getDate(90)+'. Your reference number for any future enquiries is FE'+submissionMgr.submission.Id+'. </p><h2 style="font-size: 19px; line-height: 1.315789474; margin: 0 0 30px 0;">What happens next</h2><p style="font-size: 19px; line-height: 1.315789474; margin: 0 0 30px 0;">Once the request has been approved by all individuals required, we will send an email to the person filing with instructions to review, complete and submit the request.</a> </p><p style="font-size: 19px; line-height: 1.315789474; margin: 0 0 30px 0;">It is the responsibility of directors to ensure that copies of the request have been sent to all interested parties. This can include members (usually shareholders), creditors and employees, who must be notified within 7 days of submitting the completed request. The full list of who to tell can be found in the <a href=\'https://www.gov.uk/government/publications/company-strike-off-dissolution-and-restoration\'>online guide.</a> </p></td></tr>';

        if(transactionMgr.transactionType.contains('LL'))
        {
            page =  'LL' + page;
            emailBlurb = '<tr><td width="100%" style="font-family: Helvetica, Arial, sans-serif;"><h1 class="email" style="font-weight: 700; font-size: 48px; line-height: 1.041666667; margin: 30px 0;">Request to close '+submissionMgr.submission.CompanyName__c+'</h1></td></tr><tr><td width="100%" style="font-family: Helvetica, Arial, sans-serif;"><p style="font-size: 19px; line-height: 1.315789474; margin: 0 0 30px 0;">A request to close '+submissionMgr.submission.CompanyName__c + ' ('+submissionMgr.submission.CompanyNumber__c+') whose registered office address is '+submissionMgr.submission.CompanyAddress1__c+' '+  submissionMgr.submission.CompanyPostCode__c+' <b>needs your approval</b> before it can be submitted to Companies House for processing. </br> </br>The request will be deleted if it\'s not approved and completed by '+getDate(90)+'. Your reference number for any future enquiries is FE'+submissionMgr.submission.Id+'. </p><h2 style="font-size: 19px; line-height: 1.315789474; margin: 0 0 30px 0;">What happens next</h2><p style="font-size: 19px; line-height: 1.315789474; margin: 0 0 30px 0;">Once the request has been approved by all individuals required, we will send an email to the person filing with instructions to review, complete and submit the request.</a> </p><p style="font-size: 19px; line-height: 1.315789474; margin: 0 0 30px 0;">It is the responsibility of members to ensure that copies of the request have been sent to all interested parties. This can include members (usually shareholders), creditors and employees, who must be notified within 7 days of submitting the completed request. The full list of who to tell can be found in the <a href=\'https://www.gov.uk/government/publications/limited-liability-partnership-strike-off-dissolution-and-restoration\'>online guide.</a> </p></td></tr>';
         }   


        System.debug(LoggingLevel.INFO, 'DocuSign Logging: after emailBlurb');
        
        PageReference pageRef = new PageReference('/apex/' + page);
        pageRef.getParameters().put('id', submissionMgr.submission.Id);
        
        System.debug(LoggingLevel.INFO, 'DocuSign Logging: got pageref');
        
        if (Test.IsRunningTest())
            pdfBlob = Blob.valueOf('This is a test');
        else
            pdfBlob = pageRef.getContent();
            
        System.debug(LoggingLevel.INFO, 'DocuSign Logging: got pdfBlob');

        DocuSignAPI.Document doc = DocusignLibrary.getDocument(1, EncodingUtil.base64Encode(pdfBlob), submissionMgr.submission.Form_Name__c + '_' + submissionMgr.submission.CompanyName__c + '_' + getDate(0), 'pdf');

        System.debug(LoggingLevel.INFO, 'DocuSign Logging: got doc');
        
        DocuSignAPI.CustomField custF1 = DocusignLibrary.getCustomField( 'DSFSSourceObjectId', submissionMgr.submission.Id + '~Transaction__c', 'Text');
        //DocuSignAPI.CustomField custF2 = DocusignLibrary.getCustomField( 'OfficerSigner1', submissionMgr.submission.Officers__r[0].Id + '~Officer__c', 'Text');


        //emailBlurb = '<h1 class="page-title-style-email">Request to close' + ' ' + submissionMgr.submission.CompanyName__c + ' ' + '</h1><p>A request to close' + ' ' + submissionMgr.submission.CompanyName__c + ' ' + 'needs your approval before it can be submitted to Companies House for processing. </p><table style="width: 50%;margin-right: auto;"> <thead><tr><th colspan="2" style="font-weight:bold"> <h2 class="page-title-style-email">' + submissionMgr.submission.CompanyName__c + '</h2> <tr> <th> </thead> <tr> <th style="border-bottom: 1px solid #ddd;font-weight:normal">Company number</th> <th style="border-bottom: 1px solid #ddd;font-weight:normal">' + submissionMgr.submission.CompanyNumber__c + '</th> </tr><tr> <th style="border-bottom: 1px solid #ddd;font-weight:normal">Status</th> <th style="border-bottom: 1px solid #ddd;font-weight:normal">' + submissionMgr.submission.CompanyStatus__c + '</th> </tr><tr> <th style="border-bottom: 1px solid #ddd;font-weight:normal">Incorporation date</th> <th style="border-bottom: 1px solid #ddd;font-weight:normal">' + submissionMgr.submission.CompanyIncorporationDate__c + '</th> </tr><tr> <th style="border-bottom: 1px solid #ddd;font-weight:normal">Company type</th> <th style="border-bottom: 1px solid #ddd;font-weight:normal">' + submissionMgr.submission.CompanyType__c + '</th> </tr><tr> <th style="font-weight:normal">Address</th> <th style="font-weight:normal">' + submissionMgr.submission.CompanyAddress1__c + '</th> </tr>' + (submissionMgr.submission.CompanyAddress2__c == null ? '' : ' <tr> <th></th> <th style="font-weight:normal">' + submissionMgr.submission.CompanyAddress2__c + '</th> </tr>') + (submissionMgr.submission.CompanyLocality__c == null ? '' : ' <tr> <th></th> <th style="font-weight:normal">' + submissionMgr.submission.CompanyLocality__c + '</th> </th>') + (submissionMgr.submission.CompanyRegion__c == null ? '' : ' <tr> <th></th> <th style="font-weight:normal">' + submissionMgr.submission.CompanyRegion__c + '</th> </tr>') + (submissionMgr.submission.CompanyPostCode__c == null ? '' : ' <tr> <th></th> <th style="font-weight:normal">' + submissionMgr.submission.CompanyPostCode__c + '</th> </tr>') + (submissionMgr.submission.CompanyCountry__c == null ? '' : ' <tr> <th></th> <th style="font-weight:normal">' + submissionMgr.submission.CompanyCountry__c + '</th> </tr>') + '</table><p class="paragraphs-regular"> You need to ensure that you have read and understood your responsibilities as a director in this process before approving the request. Guidance on the process of voluntarily closing a company can be found on the Companies House website using the following <a href="https://www.gov.uk/government/publications/company-strike-off-dissolution-and-restoration">link</a>.</p><p>Your reference number is FE' + submissionMgr.submission.Id +'. You\'ll need to quote this if you contact us about the request.</p><h2 class="second-level-heading">What happens next</h2><p>Once the request has been submitted you will receive an email containing a link to the submitted request.</p><p>It\'s your responsibility as a director to ensure that copies of the request have been sent to all interested parties within 7 days of submitting the completed request. Interested parties can include </p><ul> <li>members, usually shareholders</li><li>creditors</li><li>employees</li></ul></p><p class="paragraphs-regular"> Read the full list of who to tell using the following <a href="https://www.gov.uk/government/publications/company-strike-off-dissolution-and-restoration">link. </a></p><p> Failure to notify interested parties is an offence. You\'re advised to obtain and retain some proof of delivery or posting of copies to interested parties.</p><p> If the request has not been approved by all individuals required by' + ' ' + System.today().addDays(90).format() + '' + ', the request will be cancelled. </p>';


        DocuSignAPI.Envelope env = DocusignLibrary.getEnvelope(dsSetting.AccountId__c, submissionMgr.submission.Form_Name__c + ' - application for closing ' + submissionMgr.submission.CompanyName__c,  emailBlurb, dsSetting.BrandId__c);


        System.debug(LoggingLevel.INFO, 'DocuSign Logging: got initial env');
        
        //Init size of each collection of the envelope
        env = DocusignLibrary.initDocs(env, 1);
        env = DocusignLibrary.initCustomFields(env, 2);

        env = DocusignLibrary.initRecipients(env, submissionMgr.submission.Contacts__r.size());

        env = DocusignLibrary.initTabs(env, submissionMgr.submission.Contacts__r.size() * 2);
        env = DocusignLibrary.addDocs(env, doc);

        env = DocusignLibrary.addCustomFields(env, custF1);
        //env = DocusignLibrary.addCustomFields(env, custF2);

        DocuSignAPI.Notification notif = DocusignLibrary.getNotification(true);

        env = DocusignLibrary.addNotification(env, notif);

        List<Officer__c> offToUpdate = new List<Officer__c>();

        for (Integer i = 0; i < submissionMgr.submission.Contacts__r.size(); i++) {
            Contact off = submissionMgr.submission.Contacts__r[i];


            if (off.isSignatory__c) {
                //Get the corresponding officer
                Officer__c offRec = new Officer__c();

                for (Officer__c offRecord : submissionMgr.submission.Officers__r) {
                    if (String.valueOf(off.RecipientId__c) == offRecord.RecipientId__c) {
                        offRec.Id = offRecord.Id;
                    }
                }
                DocuSignAPI.RecipientCaptiveInfo capInfo;

                if (off.IsPresenter__c) {
                    capInfo = DocusignLibrary.getCaptiveInfo(off.Email);
                }


                String offName = (off.Title != null ? off.Title + ' ': '' ) + (off.FirstName != null ? off.FirstName.capitalize() + ' ' : '')  +  off.LastName.toLowerCase().capitalize();
                String recName = (off.isCorporateDirector__c == true ? off.AuthorizedSigner__c + ' pp ' + offName  : (off.isPowerOfAttorney__c == true ? off.AuthorizedSigner__c + ' pp ' + offName : offName));

                //Update off with the sent name to Docusign
                offRec.DocusignName__c = recName;
                if (offRec.Id != null) {
                    offToUpdate.add(offRec);
                }

                DocuSignAPI.ArrayOfString1 arrayOfString = new DocuSignAPI.ArrayOfString1();

                arrayOfString.CustomField = new String[1];

                arrayOfString.CustomField[0] = '##SFContact:' + off.Id + ':' + off.Name + '';

                DocuSignAPI.Recipient rec = DocusignLibrary.getRecipient(Integer.valueOf(off.RecipientId__c), 'Signer', 1, off.Email, recName, capInfo, false, arrayOfString);

                DocuSignAPI.AnchorTab anch = DocusignLibrary.getAnchorTab('/s' + Integer.valueOf(off.RecipientId__c) + '/');

                DocuSignAPI.Tab tabE = DocusignLibrary.getTab('SignHere', Integer.valueOf(off.RecipientId__c), 1, anch);

                DocuSignAPI.AnchorTab anch2 = DocusignLibrary.getAnchorTab('/sd' + Integer.valueOf(off.RecipientId__c) + '/');

                DocuSignAPI.Tab tabE2 = DocusignLibrary.getTab('DateSigned', Integer.valueOf(off.RecipientId__c), 1, anch2);

                env = DocusignLibrary.addRecipients(env, rec);

                env = DocusignLibrary.addTabs(env, tabE);
                env = DocusignLibrary.addTabs(env, tabE2);

            }
        }

        System.debug(LoggingLevel.INFO, 'DocuSign Logging: got final env');

        //Build httpHeader
        String auth = DocusignLibrary.buildAuthString( dsSetting.Username__c, dsSetting.Password__c, dsSetting.IntegratorKey__c);
        Map<String, String> httpHeader = DocusignLibrary.buildHTTPHeaders(auth);
        
        System.debug(LoggingLevel.INFO, 'DocuSign Logging: got header');

        String baseURL = Site.getBaseUrl() + '/DigitalSignature';
        
        //Here page URL contains Apex/Payment
        baseURL = baseURL + '?c=' + SecurityManager.encryptText(submissionMgr.submission.Id + AppConstants.ID_DELIM_CHAR + transactionMgr.currentStep.Id + AppConstants.ID_DELIM_CHAR + String.valueOf(DateTime.now().getTime())) ;
        
        System.debug(LoggingLevel.INFO, 'DocuSign Logging: got baseURL=' + baseURL);
        
        String result = '';

        if(!Test.isRunningTest())
            result = DocusignLibrary.sendEnvelope(dsSetting.URL__c, httpHeader, env, baseURL);
            
        System.debug(LoggingLevel.INFO, 'DocuSign Logging: sent envelope');

        //Update the sending name of each off
        update offToUpdate;

        return result;
    }


    public static String getDate(Integer addDays) {
        Date d = date.today();
        if(addDays != 0)
        {
            d = d.addDays(addDays);
        }
        String day   = d.day()   > 9 ? string.valueOf(d.day())   : '0' + string.valueOf(d.day());
        String month = d.month() > 9 ? string.valueOf(d.month()) : '0' + string.valueOf(d.month());

        return day +'-' + month + '-' + d.year();
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
                    Active__c           = true);
            return dsSettTest;
        }

        System.debug(LoggingLevel.ERROR, 'No active DocuSignSetting records exist under Custom'
                     + ' Settings. Can\'t connect to DocuSign.');
        return null;
    }

}