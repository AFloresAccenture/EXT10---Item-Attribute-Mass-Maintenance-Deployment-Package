--------------------------------------------------------------------------------------------------------------
/*
Script Name		: xxnbty_vcp_grant_command_xxnbty_msc_item_attribute_st
Date written	: 23-JUN-2015
RICEFW Object id: 
Description		: Grant command for xxnbty_msc_item_attribute_st table for EXT10
Program Style	: 

Maintenance History:
Date 		   Issue# 			    Name 				                  Remarks
-----------   -------- 				---- 				            ------------------------------------------
23-JUN-2015							Albert John Flores				Initial Development


*/
--------------------------------------------------------------------------------------------------------------
DECLARE

BEGIN 
	EXECUTE IMMEDIATE 'GRANT SELECT, INSERT, DELETE, UPDATE ON xxnbty.xxnbty_msc_item_attribute_st TO APPS'; 
		EXECUTE IMMEDIATE 'GRANT SELECT ON xxnbty.xxnbty_msc_item_attribute_st TO ACCENTURE_READONLY'; 
			EXECUTE IMMEDIATE 'GRANT SELECT ON xxnbty.XXNBTY_CATALOG_STAGING_TBL TO ACCENTURE_READONLY'; 


END; 
/
show errors;

