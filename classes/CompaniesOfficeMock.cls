@isTest
global class CompaniesOfficeMock implements HttpCalloutMock {
	global HTTPResponse respond(HTTPRequest req) {
		HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"companies":{"company":[{"companyNumber":"580066","incorporationDate":"1993-04-28T12:00:00.000+0000","status":{"code":"80","description":"Struck Off"},"registeredOfficeAddress":{"addressLines":["C/- Central Housemovers Ltd","86 Bridge Street","Bulls"],"countryCode":"NZ"},"companyName":"CENTRAL HOUSEMOVERS LIMITED","entityType":{"code":"U","description":"NZ Limited Company"}}]},"totalResults":1,"currentPage":0,"pageSize":50}');
        res.setStatus('OK');
        res.setStatusCode(200);
        return res;
	}
}