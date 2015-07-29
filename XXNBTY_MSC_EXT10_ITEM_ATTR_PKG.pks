create or replace PACKAGE        "XXNBTY_MSC_EXT10_ITEM_ATTR_PKG" 
--------------------------------------------------------------------------------------------
/*
Package Name: XXNBTY_MSC_EXT10_ITEM_ATTR_PKG
Author's Name: Albert John Flores
Date written: 06-Jun-2015
RICEFW Object: EXT10
Description: This program validates records from staging table (xxnbty_msc_item_attribute_st) to base table (msc_item_attributes).
             It will generate error report and send it to recipients.
Program Style: 

Maintenance History: 

Date			Issue#		Name					Remarks	
-----------		------		-----------				------------------------------------------------
06-Jun-2015					Albert Flores			Initial Development

*/
--------------------------------------------------------------------------------------------
IS
  g_current_user		    NUMBER(15);
  gc_limit			  		CONSTANT NUMBER := 1000;
  g_num_of_update	        NUMBER := 0;
  g_num_of_insert	        NUMBER := 0;
  g_num_of_errored_rec      NUMBER := 0;
  g_recipient				VARCHAR2(1000);
  
  --function to get lookup_code
  FUNCTION get_lookup_code(p_meaning fnd_lookups.meaning%TYPE) RETURN VARCHAR2;

  --function to get_simulation_set_id
  FUNCTION get_simulation_set_id(p_simulation_set_name msc_item_simulation_sets.simulation_set_name%TYPE) 
  RETURN msc_item_simulation_sets.simulation_set_id%TYPE;
  
  --main procedure that will execute subprocedures
  PROCEDURE item_attr_main_pr (x_errbuf   		  OUT VARCHAR2,
                               x_retcode  		  OUT VARCHAR2,
							   p_recipients		  VARCHAR2);
								   								   
  --subprocedure that will validate item attributes from staging table
  PROCEDURE validate_item_attr (x_retcode  		OUT VARCHAR2, 
                                x_errbuf   		OUT VARCHAR2);
								
  --subprocedure that will insert valid item attributes from staging to base table
  PROCEDURE insert_item_attr  (x_retcode   		OUT VARCHAR2, 
                               x_errbuf    		OUT VARCHAR2);
							   
  --subprocedure that will generate error output file. 
  PROCEDURE generate_error_report (x_retcode  	OUT VARCHAR2, 
                                   x_errbuf   	OUT VARCHAR2);
                              
							
END XXNBTY_MSC_EXT10_ITEM_ATTR_PKG; 

/

show errors;
