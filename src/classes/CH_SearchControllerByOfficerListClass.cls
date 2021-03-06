public with sharing class CH_SearchControllerByOfficerListClass {
    
    public String resultDisplay {get;set;}  
    public String CH_searchTextNumber{get;set;}
    public String results{get;set;}
    public Integer active_count {get; set;}
    
    public List<CompaniesHouse.OfficerDetails> itemsToDisplay {get;set;}
    public CompaniesHouse.OfficerList itemsToDisplayTopLevel {get;set;}
    public CompaniesHouse.Links itemsToDisplayLinks {get; set;}
    public List<CompaniesHouse.OfficerDetails> itemsToDisplayAddress {get;set;}
    
    
    //Officers List API - PageReference
    public PageReference CH_Search_functionByOfficerList(){
        
        get_CH_Search_functionByOfficerList();
           
        return null; 
    } 

    //ab
    //Get Officers List Class API
    public void get_CH_Search_functionByOfficerList() {
        
        CompaniesHouseCalloutsRequest req = new CompaniesHouseCalloutsRequest();
        CompaniesHouseCalloutsResponse res = new CompaniesHouseCalloutsResponse();
        CompaniesHouse.OfficerList jsonData = new CompaniesHouse.OfficerList ();
        
        resultDisplay = req.getRequestOfficersList(CH_searchTextNumber);
        jsonData = res.getResponseOfficerList(resultDisplay);
        system.debug('JsonData before IF : ' + jsonData);
        
        if(jsonData.total_results == null) {
        
            results = 'No records found';  
        
        }else{
            system.debug('JsonData Total Results before IF : ' + jsonData.total_results);
            this.active_count = jsonData.active_count;
            itemsToDisplay = jsonData.items;
            itemsToDisplayTopLevel = jsonData;
            itemsToDisplayAddress  = jsonData.items;
            itemsToDisplayLinks = jsonData.links; 
        }
    } 
    
}