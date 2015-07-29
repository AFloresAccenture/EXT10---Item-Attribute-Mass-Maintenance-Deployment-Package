--------------------------------------------------------------------------------------------------------
/*
	Table Name: xxnbty_msc_item_attribute_st																		
	Author's Name: Albert John Flores																				
	Date written: 06-Jun-2015																							
	RICEFW Object: EXT10																							
	Description: Staging Table for EXT10.																
	Program Style: 																									
																													
	Maintenance History:																							
																													
	Date			Issue#		Name						Remarks																
	-----------		------		-----------					------------------------------------------------					
	06-Jun-2015				 	Albert John Flores			Initial Development		

*/			
--------------------------------------------------------------------------------------------------------

CREATE TABLE xxnbty.xxnbty_msc_item_attribute_st 
(
		ITEM_SIMULATION_SET_NAME          VARCHAR2(240) 
		,ITEM_NAME						  VARCHAR2(250)		
		,ORGANIZATION_CODE				  VARCHAR2(7)
		,ATTRIBUTE_NAME					  VARCHAR2(80)
		,ATTRIBUTE_VALUE				  NUMBER		
		,PROCESS_FLAG                	  NUMBER
		,ERROR_DESCRIPTION           	  VARCHAR2 (240)
		,LAST_UPDATE_DATE				  DATE
		,LAST_UPDATED_BY				  NUMBER
		,CREATION_DATE				      DATE
		,CREATED_BY					      NUMBER
		,LAST_UPDATE_LOGIN 				  NUMBER
);

--[PUBLIC SYNONYM xxnbty_msc_item_attribute_st]
CREATE OR REPLACE PUBLIC SYNONYM xxnbty_msc_item_attribute_st for xxnbty.xxnbty_msc_item_attribute_st;
