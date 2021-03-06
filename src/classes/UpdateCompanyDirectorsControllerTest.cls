@IsTest
public with sharing class UpdateCompanyDirectorsControllerTest {
	

	@IsTest
	public static void testController(){
		CompaniesHouseTestData testData = CompaniesHouseTestData.getInstance();

        Transaction_Type__mdt testForm = CompaniesHouseTestData.getInstance().testForm;

        Transaction_Type_Step__mdt testStep1 = CompaniesHouseTestData.getInstance().testStep1;
        Account testPresenter = CompaniesHouseTestData.getInstance().presenterAccount;

        Account testCompany = CompaniesHouseTestData.getInstance().companyAccount;

        insert testPresenter;

        insert testCompany;

        Transaction__c transac = testData.tx;

        transac.Company__c = testCompany.Id;
        transac.Valid_Step_Ids__c = testStep1.Id;
        transac.officerTerminology__c = 'Test';

        insert transac;

        

        PageReference pg = Page.UpdateCompanyDirectors;
        pg.getParameters().put('c', SecurityManager.encryptText(transac.Id+AppConstants.ID_DELIM_CHAR+testStep1.Id+AppConstants.ID_DELIM_CHAR+String.valueOf(DateTime.now().getTime())));
        Test.setCurrentPage(pg);
        Cookie sessionValidity = new Cookie('SFCHS', SecurityManager.encryptText('test@test.com'+AppConstants.ID_DELIM_CHAR + String.valueOf(DateTime.now().getTime())), '', 120, true);

        pg.setCookies(new Cookie[]{sessionValidity});

        UpdateCompanyDirectorsController pay = new UpdateCompanyDirectorsController();
	}
}