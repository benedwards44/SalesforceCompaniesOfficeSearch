@isTest
public class CompaniesOfficeSearchExConTest {
	
	static testMethod void testCompaniesOfficeSearchExCon(){
		
		Account testAccount = new Account();
		testAccount.Name = 'Test Account';
		insert testAccount;
		
		PageReference testPage = Page.CompaniesOfficeSearch;
		testPage.getParameters().put('id', testAccount.Id);
		Test.setCurrentPageReference(testPage);
		
		Test.startTest();
		
		Test.setMock(HttpCalloutMock.class, new CompaniesOfficeMock());
		
		CompaniesOfficeSearchExCon testCon = new CompaniesOfficeSearchExCon(new ApexPages.StandardController(testAccount));
		testCon.companyGet('580066');
		testCon.searchAgain();
		testCon.selectedRecordNo = 0;
		testCon.selectCompany();
		testCon.saveAccountsAndContacts();
		testCon.companiesSearch('Test','580066');
		
		Test.stopTest();
		
	}

}