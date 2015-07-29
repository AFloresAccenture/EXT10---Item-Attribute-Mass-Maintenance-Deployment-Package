create or replace PACKAGE BODY        "XXNBTY_MSC_EXT10_ITEM_ATTR_PKG" 
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
  --Function to get lookup_code
  FUNCTION get_lookup_code(p_meaning fnd_lookups.meaning%TYPE)
  RETURN VARCHAR2
  IS
  
  CURSOR c_lookup
  IS SELECT lookup_code
	 FROM fnd_lookups
	 WHERE UPPER(meaning) = UPPER(p_meaning)
	 AND lookup_type = 'MSC_IMM_UPDATE_ATTRIBUTES';
	 
  v_lookup_code fnd_lookups.lookup_code%TYPE;
  BEGIN
  
	OPEN  c_lookup;
	FETCH c_lookup INTO v_lookup_code;
	CLOSE c_lookup;
	
	RETURN v_lookup_code;
  
  EXCEPTION
  WHEN OTHERS THEN
  RETURN NULL;
  
  END get_lookup_code;

  --Function to get simulation_set_id
  FUNCTION get_simulation_set_id(p_simulation_set_name msc_item_simulation_sets.simulation_set_name%TYPE)
  RETURN msc_item_simulation_sets.simulation_set_id%TYPE
  IS
  
  CURSOR c_simulation_set_id
  IS SELECT simulation_set_id
	 FROM msc_item_simulation_sets
	 WHERE UPPER(simulation_set_name) = UPPER(p_simulation_set_name);
	 
  v_simulation_set_id msc_item_simulation_sets.simulation_set_name%TYPE;
  BEGIN
  
	OPEN  c_simulation_set_id;
	FETCH c_simulation_set_id INTO v_simulation_set_id;
	CLOSE c_simulation_set_id;
	
	RETURN v_simulation_set_id;
  
  EXCEPTION
  WHEN OTHERS THEN
  RETURN NULL;
  
  END get_simulation_set_id;
  
  --main procedure that will execute subprocedures
  PROCEDURE item_attr_main_pr (x_errbuf   				OUT VARCHAR2,
							   x_retcode  				OUT VARCHAR2,
							   p_recipients		  		VARCHAR2)
  IS
	l_request_id    NUMBER := fnd_global.conc_request_id;
    l_new_filename  VARCHAR2(200);
    l_old_filename  VARCHAR2(1000);
    l_subject       VARCHAR2(100);
    l_message       VARCHAR2(1000);
	v_step			NUMBER;
	v_mess			VARCHAR2(500);
	l_error			EXCEPTION;
	
  BEGIN
  v_step := 1;
    --define current user
    g_current_user      := fnd_global.user_id;
	g_recipient			:= p_recipients;
	
	FND_FILE.PUT_LINE(FND_FILE.LOG,'Validating records from the staging table.');  
	--call procedure to validate data from Staging table
	validate_item_attr(x_retcode, x_errbuf);
	IF x_retcode = 2 THEN
		RAISE l_error;
	END IF;
  v_step := 2;	
	FND_FILE.PUT_LINE(FND_FILE.LOG,'Inserting records from staging to base table.');
	--call procedure to insert valid records from staging to base table
	insert_item_attr(x_retcode, x_errbuf);
	IF x_retcode = 2 THEN
		RAISE l_error;
	END IF;	
  v_step := 3;
	FND_FILE.PUT_LINE(FND_FILE.LOG,'Inserting records from staging to base table.');
	--call procedure to generate and send email notification
	generate_error_report(x_retcode, x_errbuf);
	IF x_retcode = 2 THEN
		RAISE l_error;
	END IF;
  v_step := 4; 
  
  EXCEPTION
  WHEN l_error THEN
        FND_FILE.PUT_LINE(FND_FILE.LOG, 'Return errbuf [' || x_errbuf || ']' );
        x_retcode := x_retcode;
  
	WHEN OTHERS THEN
    x_retcode := 2;
	v_mess := 'At step ['||v_step||'] for procedure item_attr_main_pr - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
    x_errbuf := v_mess;
    
  END item_attr_main_pr;

  PROCEDURE validate_item_attr(x_retcode             OUT VARCHAR2, 
                               x_errbuf              OUT VARCHAR2)
  IS
	--retrieve all records with NULL values in mandatory columns.
	CURSOR c_required
	IS SELECT a.rowid
	   FROM xxnbty_msc_item_attribute_st a
	   WHERE (a.item_simulation_set_name IS NULL
          OR  a.item_name				   IS NULL
          OR  a.organization_code		   IS NULL
          OR  a.attribute_name		   IS NULL
          OR  a.attribute_value          IS NULL)
		 AND  a.process_flag			   IS NULL;
		 
	--retrieve all records with simulation set name that do not exist in table msc_item_simulation_sets.
	CURSOR c_set_name
	IS SELECT  a.rowid         
	   FROM   xxnbty_msc_item_attribute_st a
	   WHERE NOT EXISTS (SELECT 1 
						 FROM   msc_item_simulation_sets b
						 WHERE	UPPER(b.simulation_set_name) = UPPER(a.item_simulation_set_name))
		AND  a.process_flag IS NULL;
		
	--retrieve all records with item name that do not exist in msc_system_items.
	CURSOR c_item_name
	IS SELECT  a.rowid
	   FROM   xxnbty_msc_item_attribute_st a
	   WHERE NOT EXISTS (SELECT 1 
						 FROM   msc_system_items b
						 WHERE	b.item_name = a.item_name
						 AND    b.plan_id = -1
						 AND 	b.sr_instance_id IN (SELECT c.instance_id 
													 FROM msc_apps_instances c
													 WHERE c.instance_code = 'EBS'))
	   AND  a.process_flag IS NULL;
	   
	--retrieve all records with organization code that do not exist in msc_trading_partners.
	CURSOR c_org_code
	IS SELECT  a.rowid
	   FROM   xxnbty_msc_item_attribute_st a
	   WHERE NOT EXISTS (SELECT 1 
						 FROM   msc_trading_partners b
						 WHERE	b.organization_code = a.organization_code)
	   AND  a.process_flag IS NULL;

	--retrieve all records with item-org combination that do not exist in msc_system_items.
	CURSOR c_item_org
	IS SELECT a.rowid
	   FROM   xxnbty_msc_item_attribute_st a
	   WHERE NOT EXISTS (SELECT 1
						 FROM   msc_system_items b
						 WHERE	b.item_name = a.item_name
						 AND	b.organization_code = a.organization_code
						 AND    b.plan_id = -1
						 AND 	b.sr_instance_id IN (SELECT c.instance_id 
													 FROM msc_apps_instances c
													 WHERE c.instance_code = 'EBS'))
	   AND  a.process_flag IS NULL;	   
  
	--retrieve all records with attribute name that do not exist in fnd_lookups.
	CURSOR c_attr_name
	IS SELECT  a.rowid
	   FROM   xxnbty_msc_item_attribute_st a
	   WHERE NOT EXISTS (SELECT 1 
						 FROM   fnd_lookups b
						 WHERE	UPPER(b.meaning) = UPPER(a.attribute_name))
	   AND  a.process_flag IS NULL;  
	   
	   
	TYPE req_tab_type 		IS TABLE OF c_required%ROWTYPE;
	TYPE item_org_tab_type	IS TABLE OF c_item_org%ROWTYPE;
	
	l_stg					req_tab_type;
	l_item_org  			item_org_tab_type;
	v_step					NUMBER;
	v_mess					VARCHAR2(500);
  
   BEGIN
   v_step := 1;
	--Error Out Records with NULL values in mandatory columns.
	OPEN c_required;
	LOOP
	FETCH c_required BULK COLLECT INTO l_stg LIMIT gc_limit;
		FORALL i in 1..l_stg.COUNT
		  UPDATE xxnbty_msc_item_attribute_st a
		  SET a.process_flag = '3' 
			 ,a.error_description = 'Missing value for required column/s.'
		  WHERE a.rowid = l_stg(i).rowid;
		
		g_num_of_errored_rec := g_num_of_errored_rec + l_stg.COUNT;
		
		EXIT WHEN c_required%NOTFOUND;
	  COMMIT;
	END LOOP;
	CLOSE c_required;
	COMMIT;
	--delete contents of array for reuse.
	l_stg.DELETE();
	v_step := 2;
	--Error Out Records with invalid set name 
	OPEN c_set_name;
	LOOP
	FETCH c_set_name BULK COLLECT INTO l_stg LIMIT gc_limit;
		FORALL i in 1..l_stg.COUNT
		  UPDATE xxnbty_msc_item_attribute_st a
		  SET a.process_flag = '3' 
			 ,a.error_description = 'Simulation Set name does not exist in msc_item_simulation_sets.'
		  WHERE a.rowid = l_stg(i).rowid;
		
		g_num_of_errored_rec := g_num_of_errored_rec + l_stg.COUNT;
		
		EXIT WHEN c_set_name%NOTFOUND;
	  COMMIT;
	END LOOP;
	CLOSE c_set_name;
	COMMIT;
	--delete contents of array for reuse.
	l_stg.DELETE();	
	v_step := 3;
	/*
	--Error Out Records with invalid item name 
	OPEN c_item_name;
	LOOP
	FETCH c_item_name BULK COLLECT INTO l_stg LIMIT gc_limit;
		FORALL i in 1..l_stg.COUNT
		  UPDATE xxnbty_msc_item_attribute_st
		  SET process_flag = '3' 
			 ,error_description = 'Item name does not exist in msc_system_items.'; 
		
		g_num_of_errored_rec := g_num_of_errored_rec + l_stg.COUNT;
		
		EXIT WHEN c_item_name%NOTFOUND;
	  COMMIT;
	END LOOP;
	CLOSE c_item_name;
	COMMIT;
	--delete contents of array for reuse.
	l_stg.DELETE();
	*/
	v_step := 4;
	--Error Out Records with invalid organization code 
	OPEN c_org_code;
	LOOP
	FETCH c_org_code BULK COLLECT INTO l_stg LIMIT gc_limit;
		FORALL i in 1..l_stg.COUNT
		  UPDATE xxnbty_msc_item_attribute_st a
		  SET a.process_flag = '3' 
			 ,a.error_description = 'Organization code does not exist in msc_trading_partners.'
		  WHERE a.rowid = l_stg(i).rowid;
		
		g_num_of_errored_rec := g_num_of_errored_rec + l_stg.COUNT;
		
		EXIT WHEN c_org_code%NOTFOUND;
	  COMMIT;
	END LOOP;
	CLOSE c_org_code;
	COMMIT;
	--delete contents of array for reuse.
	l_stg.DELETE();		  
	v_step := 5;	  
	--Error Out Records with item-org combination not existing in msc_system_items 
	OPEN c_item_org;
	LOOP
	FETCH c_item_org BULK COLLECT INTO l_item_org LIMIT gc_limit;
		FORALL i in 1..l_item_org.COUNT
		  UPDATE xxnbty_msc_item_attribute_st a
		  SET a.process_flag = '3' 
			 ,a.error_description = 'Item - Org combination does not exist in msc_system_items.'
		  WHERE a.rowid = l_item_org(i).rowid;		
		
		g_num_of_errored_rec := g_num_of_errored_rec + l_item_org.COUNT;
		
		EXIT WHEN c_item_org%NOTFOUND;
	  COMMIT;
	END LOOP;
	CLOSE c_item_org;
	COMMIT;
	--delete contents of array for reuse.
	l_item_org.DELETE();
	v_step := 6;
	--Error Out Records with invalid attribute name 
	OPEN c_attr_name;
	LOOP
	FETCH c_attr_name BULK COLLECT INTO l_stg LIMIT gc_limit;
		FORALL i in 1..l_stg.COUNT
		  UPDATE xxnbty_msc_item_attribute_st a
		  SET a.process_flag = '3' 
			 ,a.error_description = 'Attribute name does not exist in fnd_lookups.'
		  WHERE a.rowid = l_stg(i).rowid;
		
		g_num_of_errored_rec := g_num_of_errored_rec + l_stg.COUNT;
		
		EXIT WHEN c_attr_name%NOTFOUND;
	  COMMIT;
	END LOOP;
	CLOSE c_attr_name;
	COMMIT;
	v_step := 7;
	--delete contents of array for reuse.
	l_stg.DELETE();
	
	EXCEPTION
    WHEN OTHERS THEN
    x_retcode := 2;
	v_mess := 'At step ['||v_step||'] for procedure validate_item_attr - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
    x_errbuf := v_mess;  
	  
  END validate_item_attr;	  
		  
  PROCEDURE insert_item_attr(x_retcode             OUT VARCHAR2, 
                               x_errbuf              OUT VARCHAR2)
  IS
	--retrieve all valid records that are existing in the base table to be updated
	CURSOR c_valid_rec_update
	IS
	SELECT  XXNBTY_MSC_EXT10_ITEM_ATTR_PKG.get_simulation_set_id(mis.item_simulation_set_name) simulation_set_id, 
			msc.plan_id, 
			msc.organization_id, 
			msc.inventory_item_id, 
			msc.sr_instance_id, 
			XXNBTY_MSC_EXT10_ITEM_ATTR_PKG.get_lookup_code(mis.attribute_name) column_name, 
			mis.attribute_value, 
			mis.last_update_date , 
			mis.last_updated_by , 
			mis.creation_date , 
			mis.created_by
	FROM xxnbty_msc_item_attribute_st mis
				,msc_system_items msc
	WHERE mis.item_name 		= msc.item_name
	AND	  mis.organization_code = msc.organization_code
	AND	  msc.plan_id 			= -1
	AND   mis.process_flag IS NULL
	AND EXISTS (SELECT 1
				FROM msc_item_attributes mia
				WHERE mia.simulation_set_id = XXNBTY_MSC_EXT10_ITEM_ATTR_PKG.get_simulation_set_id(mis.item_simulation_set_name)
				AND	  mia.plan_id			= msc.plan_id   
				AND	  mia.organization_id 	= msc.organization_id 
				AND	  mia.inventory_item_id = msc.inventory_item_id
				AND	  mia.sr_instance_id 	= msc.sr_instance_id);
		
	--retrieve all valid records that are not existing in the base table to be inserted.		
	CURSOR c_valid_rec_insert
	IS 
	SELECT  XXNBTY_MSC_EXT10_ITEM_ATTR_PKG.get_simulation_set_id(mis.item_simulation_set_name) simulation_set_id, 
			msc.plan_id, 
			msc.organization_id, 
			msc.inventory_item_id, 
			msc.sr_instance_id, 
			XXNBTY_MSC_EXT10_ITEM_ATTR_PKG.get_lookup_code(mis.attribute_name) column_name, 
			mis.attribute_value, 
			mis.last_update_date , 
			mis.last_updated_by , 
			mis.creation_date , 
			mis.created_by
	FROM xxnbty_msc_item_attribute_st mis
				,msc_system_items msc
	WHERE mis.item_name 		= msc.item_name
	AND	  mis.organization_code = msc.organization_code
	AND	  msc.plan_id 			= -1
	AND   mis.process_flag IS NULL
	AND NOT EXISTS (SELECT 1
				FROM msc_item_attributes mia
				WHERE mia.simulation_set_id = XXNBTY_MSC_EXT10_ITEM_ATTR_PKG.get_simulation_set_id(mis.item_simulation_set_name)
				AND	  mia.plan_id			= msc.plan_id   
				AND	  mia.organization_id 	= msc.organization_id 
				AND	  mia.inventory_item_id = msc.inventory_item_id
				AND	  mia.sr_instance_id 	= msc.sr_instance_id);
	
	TYPE valid_upd_type	IS TABLE OF c_valid_rec_update%ROWTYPE;
	TYPE valid_ins_type	IS TABLE OF c_valid_rec_insert%ROWTYPE;
	
	l_valid_rec_upd					valid_upd_type;
	l_valid_rec_insert				valid_ins_type;
	
	l_update_query		VARCHAR2(4000);
	l_insert_query		VARCHAR2(4000);
	v_step			NUMBER;
	v_mess			VARCHAR2(500);
	
  BEGIN
  v_step := 1;
  --Update Records that are existing in the base table with the new values
  OPEN c_valid_rec_update;
  LOOP
  FETCH c_valid_rec_update BULK COLLECT INTO l_valid_rec_upd LIMIT gc_limit;
  v_step := 2;
	FOR i in 1..l_valid_rec_upd.COUNT
		LOOP
			--Update records in the base table that is existing already
			l_update_query := ' UPDATE msc_item_attributes '
							||' SET '|| l_valid_rec_upd(i).column_name ||' = '||l_valid_rec_upd(i).attribute_value|| ' '
							||' ,last_update_date = ' ||'SYSDATE'|| ' '
							||' ,last_updated_by = ' ||g_current_user|| ' '
							||' WHERE simulation_set_id = '||l_valid_rec_upd(i).simulation_set_id|| ' '
							||' AND plan_id = '||l_valid_rec_upd(i).plan_id|| ' '
							||' AND organization_id = '||l_valid_rec_upd(i).organization_id|| ' '
							||' AND inventory_item_id = '||l_valid_rec_upd(i).inventory_item_id|| ' '
							||' AND sr_instance_id = '||l_valid_rec_upd(i).sr_instance_id|| ' ';
							
			FND_FILE.PUT_LINE(FND_FILE.LOG,'Query for l_update_query [ ' || l_update_query ||' ] '); 
			
			EXECUTE IMMEDIATE l_update_query;
		END LOOP;
	g_num_of_update := g_num_of_update + l_valid_rec_upd.COUNT;	
	v_step := 3;
	EXIT WHEN c_valid_rec_update%NOTFOUND;
	v_step := 4;
	COMMIT;
   END LOOP;
   CLOSE c_valid_rec_update;
   v_step := 5;
   --delete array for reuse
   --l_valid_rec.DELETE();
   v_step := 6;
   --Insert Records that are not existing in the base table.
   OPEN c_valid_rec_insert;
   LOOP
   v_step := 7;
   FETCH c_valid_rec_insert BULK COLLECT INTO l_valid_rec_insert LIMIT gc_limit;
	FOR i in 1..l_valid_rec_insert.COUNT
		LOOP
			--Insert Valid records in the base table
			l_insert_query := 'INSERT INTO msc_item_attributes (simulation_set_id, plan_id, organization_id, inventory_item_id, sr_instance_id, last_update_date, last_updated_by, creation_date, created_by, '|| l_valid_rec_insert(i).column_name || ' ) '
							||' VALUES ( '|| l_valid_rec_insert(i).simulation_set_id || ' , ' 
							|| l_valid_rec_insert(i).plan_id || ' , ' 
							|| l_valid_rec_insert(i).organization_id || ' , ' 
							|| l_valid_rec_insert(i).inventory_item_id || ' , ' 
							|| l_valid_rec_insert(i).sr_instance_id || ' , ' 
							|| 'SYSDATE' || ' , ' 
							|| g_current_user || ' , ' 
							|| 'SYSDATE' || ' , ' 
							|| g_current_user || ' , ' 
							|| l_valid_rec_insert(i).attribute_value || ' ) ';
		
			FND_FILE.PUT_LINE(FND_FILE.LOG,'Query for l_insert_query [ ' || l_insert_query ||' ] ');
		
			EXECUTE IMMEDIATE l_insert_query;
		END LOOP;
	g_num_of_insert := g_num_of_insert + l_valid_rec_insert.COUNT;	
	v_step := 8;	
	EXIT WHEN c_valid_rec_insert%NOTFOUND;
	v_step := 9;
	COMMIT;
   END LOOP;
   CLOSE c_valid_rec_insert;
	v_step := 10;
	--Update process flag of processed records
	UPDATE xxnbty_msc_item_attribute_st
	SET process_flag = 5
	WHERE process_flag IS NULL
	AND error_description IS NULL;
	v_step := 11;
	COMMIT;	
	v_step := 12;
  EXCEPTION
   WHEN OTHERS THEN
    x_retcode := 2;
	v_mess := 'At step ['||v_step||'] for procedure insert_item_attr - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
    x_errbuf := v_mess;
  
  END insert_item_attr;
  
  --subprocedure that will generate error output file. 
  PROCEDURE generate_error_report (x_retcode  	OUT VARCHAR2, 
                                   x_errbuf   	OUT VARCHAR2)
  IS
   v_request_id    		NUMBER := fnd_global.conc_request_id;  

		CURSOR c_gen_error 
		IS
		SELECT ITEM_SIMULATION_SET_NAME 
			   || ',' ||ITEM_NAME			
			   || ',' ||ORGANIZATION_CODE	
			   || ',' ||ATTRIBUTE_NAME		
			   || ',' ||ATTRIBUTE_VALUE	
			   || ',' ||ERROR_DESCRIPTION       
			   || ',' ||CREATION_DATE		ITEM_ATTR_TABLE       
				FROM xxnbty_msc_item_attribute_st 
				WHERE process_flag = 3 AND TRUNC(creation_date) = TRUNC(SYSDATE);
				
		CURSOR c_get_file ( p_det_req_id       NUMBER)
		IS
		SELECT outfile_name
		  FROM fnd_concurrent_requests
		 WHERE request_id = p_det_req_id;			
						
	TYPE err_tab_type		   IS TABLE OF c_gen_error%ROWTYPE;
	  
	l_detailed_error_tab	   err_tab_type; 
	v_old_filename			   VARCHAR2(1000);
	v_new_filename			   VARCHAR2(200);
	v_subject				   VARCHAR2(100);
	v_message				   VARCHAR2(240);
	v_recipient				   VARCHAR2(240);
	v_cc					   VARCHAR2(240);
	v_bcc					   VARCHAR2(240);
	v_submit_id				   NUMBER;
	v_step          		   NUMBER;
	v_mess          		   VARCHAR2(500);
	v_instance				   VARCHAR2(30);
	
   BEGIN
	v_step := 1;

		FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'ITEM_SIMULATION_SET_NAME,ITEM_NAME,ORGANIZATION_CODE,ATTRIBUTE_NAME,ATTRIBUTE_VALUE,ERROR_DESCRIPTION,CREATION_DATE');
		
		OPEN c_gen_error;
	v_step := 2;	
		FETCH c_gen_error BULK COLLECT INTO l_detailed_error_tab;
		FOR i in 1..l_detailed_error_tab.COUNT
			LOOP
				FND_FILE.PUT_LINE(FND_FILE.OUTPUT, l_detailed_error_tab(i).ITEM_ATTR_TABLE );
			END LOOP;
		CLOSE c_gen_error;
	v_step := 3;
	
		OPEN c_get_file (v_request_id);		
		FETCH c_get_file INTO v_old_filename;
		CLOSE c_get_file;	
		
		SELECT DECODE(NAME,'NBTYPP01','Production Instance ' , 'Non Production Instance') INTO v_instance FROM v$database;
	v_step := 4;	
		--if there are errors, we will send email notification
		IF g_num_of_errored_rec > 0 THEN
			v_new_filename := 'XXNBTY_EXT10_ITEM_ATTR_ERRORS_' || TO_CHAR(SYSDATE, 'YYYYMMDD') || '.csv';
			v_message	   := 'Hi,\n\nAttached is the Mass Item Attribute Error Report.\n\nCreated Records: '||g_num_of_insert||'\nUpdated Records: '||g_num_of_update||'\nError Records: '||g_num_of_errored_rec||'\n\n*****This is an auto-generated e-mail. Please do not reply.*****';
		ELSE 
			v_new_filename := 'NONE';
			v_message	   := 'Hi,\n\nSuccessfully uploaded Mass Item Attributes.\n\nCreated Records: '||g_num_of_insert||'\nUpdated Records: '||g_num_of_update||'\nError Records: '||g_num_of_errored_rec||'\n\n*****This is an auto-generated e-mail. Please do not reply.*****';
		END IF;
	v_step := 5;	
		v_subject	   := 'VCP Item Attribute File Upload Status Report - '||v_instance||' ';
		
		--v_recipient	   := 'sanjay.p.sinha@accenture.com,albert.john.j.flores@accenture.com';
		v_cc		   := '';
		v_bcc		   := '';
	v_step := 6;	
		--Call the concurrent program to send email notification
		v_submit_id := FND_REQUEST.SUBMIT_REQUEST(application  => 'XXNBTY'
											   ,program      => 'XXNBTY_VCP_SEND_EMAIL_LOG'
											   ,start_time   => TO_CHAR(SYSDATE,'DD-MON-YYYY HH:MI:SS')
											   ,sub_request  => FALSE
											   ,argument1    => v_new_filename
											   ,argument2    => v_old_filename
											   ,argument3    => g_recipient
											   ,argument4    => v_cc
											   ,argument5    => v_bcc
											   ,argument6    => v_subject
											   ,argument7    => v_message);
												   
	v_step := 7;											   
		
	EXCEPTION
		WHEN OTHERS THEN
		  x_retcode := 2;
		  v_mess := 'At step ['||v_step||'] - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
		  x_errbuf  := v_mess;
 
  END generate_error_report;

END XXNBTY_MSC_EXT10_ITEM_ATTR_PKG;

/

show errors;
