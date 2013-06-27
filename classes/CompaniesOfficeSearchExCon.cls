public class CompaniesOfficeSearchExCon {
	
	public Account sfAccount {get;set;}
	static final String C_SOURCE_COMPANIES = 'Companies Office';
	static final String C_COMPANIES_AUTHENTICATION_KEY_ID = 'DxPGa4O6JGK4JzY4';
	static final String C_COMPANIES_SECRET_AUTHENTICATION_KEY = 'Tp9DWQwuOZwKD2qU1FZ2oBMzvUz93rT7LbT721HW';
	static final String C_COMPANIES_REST_ACCEPT = 'application/json';
	static final String C_COMPANIES_REST_HOST = 'eat.businessdata.govt.nz';
	static final String C_COMPANIES_REST_ENDPOINT_SEARCH = '/data/app/ws/rest/companies/entity/search/v1.0/';
	static final String C_COMPANIES_REST_ENDPOINT_DETAIL = '/data/app/ws/rest/companies/entity/v1.0/';
	
	static final String C_COMPANIES_TOKEN_CONTACT_DIRECTOR = 'director';
	
	public List<clsSearchAccount> companiesSearchResults {get;set;}
	public clsSearchAccount selectedAccount { get; set; }
	public Boolean resultsFound {get;set;}
	public Integer selectedRecordNo {get;set;}
	public Boolean renderServiceAddress {get;set;}

	public CompaniesOfficeSearchExCon(ApexPages.StandardController controller){
		sfAccount = [Select Id, Name, Company_Number__c, Entity_Type__c , Company_Status__c, Companies_Office_Last_Update__c,
							BillingStreet, BillingCity, BillingState, BillingPostalCode,
							ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode		
						 From Account Where Id = :ApexPages.currentPage().getParameters().get('id')];
		string encodeAccountName = EncodingUtil.urlEncode(removeLtd(sfAccount.Name),'UTF-8');
		encodeAccountName = encodeAccountName.replace('+','%20');
		companiesSearchResults = companiesSearch(encodeAccountName,sfAccount.Company_number__c);
		if (companiesSearchResults.size()== 0){
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO,'There were no matches returned for the Companies Office search. Please try searching a different company name.'));
		}
		renderServiceAddress = false;
	}
	
	public static clsSearchAccount companyGet(String companyNo) {
		List<clsSearchAccount> companiesDetail;

		Map<String,String> headers = new Map<String,String>();

		String sigDateTime = Datetime.now().formatGMT('EEE, dd MMM yyyy HH:mm:ss z');
		String endPoint = C_COMPANIES_REST_ENDPOINT_DETAIL + companyNo;

		String signature = constructCompaniesAuthSignature(sigDateTime, endPoint);
		headers.put('Authorization', signature);
		headers.put('Accept', C_COMPANIES_REST_ACCEPT);
		headers.put('Date', sigDateTime);
		String query = 'http://' + C_COMPANIES_REST_HOST + C_COMPANIES_REST_ENDPOINT_DETAIL + companyNo;
		HttpResponse response = RESTQuery(query, C_SOURCE_COMPANIES, headers);
		
		if (response != null){ 
			companiesDetail = loadCompaniesAccounts(response);
		}

		if (companiesDetail != null && !companiesDetail.isEmpty()) {		
			return companiesDetail[0];
		} else {
			return null;
		}		
	}
	
	public static List<clsSearchAccount> companiesSearch(String acctName, String companyNo) {

		List<clsSearchAccount> companiesSearchResults;
		Map<String,String> headers = new Map<String,String>();
		String sigDateTime = Datetime.now().formatGMT('EEE, dd MMM yyyy HH:mm:ss z');
		String endPoint;
		if (companyNo != null && companyNo != '') {
			endPoint = C_COMPANIES_REST_ENDPOINT_SEARCH + companyNo;
		} else {
			endPoint = C_COMPANIES_REST_ENDPOINT_SEARCH + acctName;
		}
		
		String signature = constructCompaniesAuthSignature(sigDateTime, endPoint);
		headers.put('Authorization', signature);
		headers.put('Accept', C_COMPANIES_REST_ACCEPT);
		headers.put('Date', sigDateTime);
		
		String query = 'http://' + C_COMPANIES_REST_HOST + endPoint;
		
		HttpResponse response = RESTQuery(query, C_SOURCE_COMPANIES, headers);
		if (response != null) {
			companiesSearchResults = loadCompaniesAccounts(response);
		}
		if (companiesSearchResults != null){
			return companiesSearchResults;
		} else {
			return new List<clsSearchAccount>();
		}
	}
	
	///==============================================================================
	///constructCompaniesAuthSignature
	///Construct signature to be used in REST query
	///==============================================================================
	public static String constructCompaniesAuthSignature(String sigDateTime, String endPoint) {
		String signature;
		String sigSource = 'GET\n' + C_COMPANIES_REST_HOST;
		sigSource += '\n' + endPoint;
		sigSource += '\n' + sigDateTime;
		sigSource += '\n' + C_COMPANIES_AUTHENTICATION_KEY_ID;
		sigSource += '\n' + C_COMPANIES_REST_ACCEPT;
		sigSource += '\n';
		Blob mac = Crypto.generateMac(	'hmacSHA256'
										, Blob.valueOf(sigSource)
										, Blob.valueOf(C_COMPANIES_SECRET_AUTHENTICATION_KEY));
		String macUrl = EncodingUtil.base64Encode(mac);
		signature = C_COMPANIES_AUTHENTICATION_KEY_ID + ':' + macUrl;
		return signature;		
	}
	
	///==============================================================================
	///RESTQuery
	///Performs a synchronous REST API call
	///==============================================================================
	public static HttpResponse RESTQuery(String url, String sourceName, Map<String,String> headers) {

		List<clsSearchAccount> searchResults;
			
		Http http = new Http();
	    HttpRequest req = new HttpRequest();
	    req.setEndpoint(url);
	    req.setMethod('GET');

		if (headers != null) {
			for (String headerKey : headers.keySet()) {
			    req.setHeader(headerKey, headers.get(headerKey));
			}
		}	    

	    HttpResponse response;
		try {
	    	response = http.send(req);
		} catch (Exception ex) {
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'There was an error connecting to the '+sourceName+' database. Please contact your application administrator for assistance. Error message: ' + ex));
			return null;
		}
		if (response.getStatus() == 'OK') {
			return response;
		} else {
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'There was an error connecting to the '+sourceName+' database. Please contact your application administrator for assistance. Error message: ' + response.getBody()));
			return null;
		}

	}
	
	public static List<clsSearchAccount> loadCompaniesAccounts(HttpResponse response) {
		integer counter = 0;
		JSONParser parser = JSON.createParser(response.getBody());
		List<clsSearchAccount> companies = new List<clsSearchAccount>();
		clsSearchAccount company;
		clsSearchContact companyContact;
		String ser, ser2;
		boolean contactFound = false;
		//attempt to load account from json 
		company = (clsSearchAccount)parser.readValueAs(clsSearchAccount.class);
		if (company.companyNumber != null) {
			ser = JSON.serialize(company);

        	company.recordNo = counter++;
        	company.loadCompaniesAccount();
        	parser = JSON.createParser(response.getBody());
        	while(parser.nextToken() != null) {
				if (parser.getCurrentToken() == JSONToken.FIELD_NAME && parser.getText() == C_COMPANIES_TOKEN_CONTACT_DIRECTOR) {
					parser.nextToken();
					if (parser.getCurrentToken() == JSONToken.START_ARRAY) {
						while (parser.nextToken() != null) {
							if (parser.getCurrentToken() == JSONToken.START_OBJECT) {
								companyContact = (clsSearchContact)parser.readValueAs(clsSearchContact.class);
								ser2 = JSON.serialize(companyContact);
								company.contacts.add(companyContact);
							} else if (parser.getCurrentToken() == JSONToken.END_ARRAY) break;	
						}
					}
				}
        	}
        	companies.add(company);
		} else {
			//failed - must be list of companies 
			parser = JSON.createParser(response.getBody());
			while (parser.nextToken() != null) {
				if (parser.getCurrentToken() == JSONToken.START_ARRAY) {
					while (parser.nextToken() != null) {
						if (parser.getCurrentToken() == JSONToken.START_OBJECT) {
							company = (clsSearchAccount)parser.readValueAs(clsSearchAccount.class);
							ser = JSON.serialize(company);
	                    	company.recordNo = counter++;
	                    	company.loadCompaniesAccount();
	                    	companies.add(company);
						}
					}
				}
			}
		}
		return companies;
	}
	
	public void selectCompany() {
		renderServiceAddress = true;
		clsSearchAccount selectedSearchAccount = companiesSearchResults.get(selectedRecordNo);
		selectedAccount = companyGet(selectedSearchAccount.account.Company_number__c);
		if (!ApexPages.hasMessages()){
			selectedAccount.LoadChildContacts();
		}
	}
	
	public class clsSearchAccount {
		public Integer recordNo {get;set;}
		public Account account {
    		get {
    		if (this.account == null) this.account = new Account();
    			return this.account;
    		} set;
		}
		public List<clsSearchContact> contacts {
			get {
				if (this.contacts == null) this.contacts = new List<clsSearchContact>();
				return this.contacts;
			} set;
		}
		
		//JSON response attributes - names must match JSON attributes exactly
		//company
		//activeDirectors not able to be loaded directly into class due to complex json structure - done within loadCompaniesAccounts
		public clsCompanyAddress registeredOfficeAddress {get; private set;}
		public clsCompanyAddress addressForService {get; private set;}
		public clsCompanyAttributePair entityType {get; private set;}
		public clsCompanyAttributePair status {get; private set;}
		public String companyNumber;
		public String incorporationDate;
		public String companyName;
		
    	public clsSearchAccount() {}

    	public clsSearchAccount(Integer recordNo) {
    		this.RecordNo = recordNo;
    	}

		public void loadCompaniesAccount() {
			this.account.name =							toTitleCase(this.companyName);
			this.account.Company_number__c =				this.companyNumber;
			if (this.registeredOfficeAddress != null) {
				this.account.BillingCountry =				this.registeredOfficeAddress.countryCode;
				if (registeredOfficeAddress.addressLines != null && !registeredOfficeAddress.addressLines.isEmpty()) {
					for (Integer counter = 0 ; counter < registeredOfficeAddress.addressLines.size(); counter++) {
						if (counter == 0) this.account.BillingStreet =		this.registeredOfficeAddress.addressLines[0];
						if (counter == 1) this.account.BillingCity =		this.registeredOfficeAddress.addressLines[1];
						if (counter == 2) this.account.BillingState =		this.registeredOfficeAddress.addressLines[2];
						if (counter == 3) this.account.BillingPostalCode =	this.registeredOfficeAddress.addressLines[3];
					}
				}
			}
			if (this.addressForService != null) {
				this.account.ShippingCountry =				this.addressForService.countryCode;
				if (addressForService.addressLines != null && !addressForService.addressLines.isEmpty()) {
					for (Integer counter = 0 ; counter < addressForService.addressLines.size(); counter++) {
						if (counter == 0) this.account.ShippingStreet =		this.addressForService.addressLines[0];
						if (counter == 1) this.account.ShippingCity =		this.addressForService.addressLines[1];
						if (counter == 2) this.account.ShippingState =		this.addressForService.addressLines[2];
						if (counter == 3) this.account.ShippingPostalCode =	this.addressForService.addressLines[3];
					}
				}
			}
			if (this.entityType != null) {
				this.account.Entity_Type__c = this.entityType.description;
			}
			if (this.status != null){
				this.account.Company_Status__c = this.status.description;
			}
		}
		
		public void LoadChildContacts() {
			for (clsSearchContact childContact: this.contacts) {
				childContact.LoadContact();
			}
		}
		
		//fetch contact records from child contact class instances		
		public List<Contact> getContacts() {
			List<Contact> contacts = new List<Contact>();
			for (clsSearchContact childContact: this.contacts) {
				contacts.add(childContact.contact);
			}
			return contacts;
		}
		
		//if account has been inserted then child contacts will be related to it
		public void setParentForContacts() {
			if (this.account.Id != null) {
				for (clsSearchContact childContact: this.contacts) {
					childContact.contact.AccountId = this.account.Id;
				}
			}
		}

	}
	

	public class clsSearchContact {

    	public Contact contact{
    		get {
    		if (this.contact == null) this.contact = new Contact();
    			return this.contact;
    		} set;
		}
		
		public Boolean insertContact {get;set;}
		public String FirstName; 
		public String LastName;
		public clsCompanyAddress physicalAddress {get; private set;}

		public clsSearchContact() {}

		public void LoadContact() {
			this.contact.LastName =			toTitleCase(this.LastName);
			this.contact.FirstName =		toTitleCase(this.FirstName);
			if (this.physicalAddress != null) {
				this.contact.OtherCountry =				this.physicalAddress.countryCode;
				if (physicalAddress.addressLines != null && !physicalAddress.addressLines.isEmpty()) {
					for (Integer counter = 0 ; counter < physicalAddress.addressLines.size(); counter++) {
						if (counter == 0) this.contact.OtherStreet =		this.physicalAddress.addressLines[0];
						if (counter == 1) this.contact.OtherCity =			this.physicalAddress.addressLines[1];
						if (counter == 2) this.contact.OtherState =			this.physicalAddress.addressLines[2];
						if (counter == 3) this.contact.OtherPostalCode =	this.physicalAddress.addressLines[3];
					}
				}
			}
		}
	}

	
	public class clsCompanyAddress { 
		public String[] addressLines;
		public String countryCode;
	}

	public class clsCompanyAttributePair {
		public String code;
		public String description;
	}
	
	public PageReference saveAccountsAndContacts(){
		try {
			sfAccount.Companies_Office_Last_Update__c = system.now();
			update sfAccount;
		} catch (Exception ex){
			ApexPages.addMessages(ex);
			return null;
		}

		List<Contact> insertContacts = new List<Contact>();
		for (clsSearchContact contact :selectedAccount.contacts){
			if (contact.insertContact){
				contact.contact.AccountId = sfAccount.Id;
				insertContacts.add(contact.contact);
			}
		}
		if (insertContacts.size() > 0){
			try {
				insert insertContacts;
			} catch (Exception ex){
				ApexPages.addMessages(ex);
				return null;
			}
		}
		return new PageReference('/'+sfAccount.Id);
	}
	
	private String removeLtd(string value){
		value = value.replace(' ltd', '');
		value = value.replace(' Ltd', '');
		value = value.replace(' LTD', '');
		value = value.replace(' limited', '');
		value = value.replace(' Limited', '');
		value = value.replace(' LIMITED', '');
		return value;
	}
	
	public void searchAgain(){
		string encodeAccountName = EncodingUtil.urlEncode(removeLtd(sfAccount.Name),'UTF-8');
		encodeAccountName = encodeAccountName.replace('+','%20');
		companiesSearchResults = companiesSearch(encodeAccountName,null);
		if (companiesSearchResults.size()== 0){
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO,'There were no matches returned for the Companies Office search. Please try searching a different company name.'));
		}
		renderServiceAddress = false;
	}

	private static String toTitleCase(String phrase){
		String titlePhrase = '';
 		Set<String> forceLower = new Set<String>{'of', 'the', 'for', 'and', 'a', 'to', 'at' ,'an', 'but', 'if', 'or', 'nor'};

  		if (phrase != null && phrase.length() > 0){
    		String[] splitPhrase = phrase.trim().split(' ');
			
			for(integer i = 0; i < splitPhrase.size(); i++){
				if (splitPhrase[i] != ''){
					if(!forceLower.contains(splitPhrase[i].toLowerCase()) || i == 0 || i == (splitPhrase.size()-1) ){
						titlePhrase += (splitPhrase[i].substring(0,1).toUpperCase())+(splitPhrase[i].substring(1).toLowerCase())+' ';
					} else {
	        			titlePhrase += splitPhrase[i].toLowerCase()+' ';
	      			}
				}
    		}
    		titlePhrase = titlePhrase.trim();
		}
		return titlePhrase;
	}
	
}