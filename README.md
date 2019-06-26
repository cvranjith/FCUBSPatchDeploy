# FCUBSPatchDeploy
Automate patch deploy patch for FCUBS that can deploy EAR(s) on weblogic and compile DB units on Oracle DB.
This bash script is tested in linux server and is meant for silent installation of patches

Usage:
./deploy.sh /path/to/property/file.prop /path/to/patch_directory

    call deploy.sh with 2 arguments
       arg#1 property file that would              the required environment variables
	   arg#2 directory that contains patch units

Notes:
    1) The script should be run in a machine having WLST configured, and also should have connection to Oracle DB using sql*plus.
       Ideally this would be run from Weblogic server where both the above will be available.
    2) property file should export the below environment variables. Ideally there will be one property file per environment.
	          
		 Variable name                   Particulars
		 DBCONN                          DB connection properties that will be used by sql*plus to connect to DB (usually user/password@tnsname)
		 JS_LOCATION                     Directory on the WLS server where JS files will be copied
		 UIXML_LOCATION                  Directory on the WLS server where UIXML files will be copied
		 UIXML_LANG                      UIXML Language sub-directory(ies). If there are multiple Language Directories, separate them with spaces
		 PATCH_BACKUP_LOCATION           Backup of JS/UIXML/EARs will be copied into this directory under patch sub-directory, before applying the patch
		 PATCH_LOG_LOCATION              A log file will be written in this directory
		 WLS_USERNAME                    User Name to connect to WLS
		 WLS_PASSWORD                    Weblgoc user Password
		 WLS_URL                         Weblogic Admin Server URL
		 DB_FILE_ORDER                   Database file extensions in the order in which it has to be applied.
		 wlst                            Path to wlst.sh. wlst.sh will be under oracle_common/common/bin/ folder in Weblgoic 12c
		 source /fullpath/setWlstEnv.sh  --Add this line before exporting ORACLE_HOME.This is required for WLST to work.
		 ORACLE_HOME                     Oracle Home for sql*plus
		 
		 ps: if you do not want to save the password in the property files, then you change it to accept the password at user prompts and then construct the environment variables accordingly.
		 e.g. 
             echo    "Enter Schema Password           :"
             read -s db_pwd
			 export DB_CONN=dbschema/${db_pwd}@tnsname

             echo    "Enter WebLogic Server Password  :"
             read -s WLS_PASSWORD

	3) The patch_directory can be any directory wherein the units will be kept in respective sub-directories.
	   The script will scan through all the files and sub-directories under this patch_directory, and identify the units to apply.
	   The DB units will be identified based on the extensions given in "DB_FILE_ORDER"
	   The JS files should have .js extensions
	   UIXML files will have .XML extension. UIXML files should be kept in the respective LANG folders
	   EAR files should have .ear extension. The EAR files should be already present in WLS deployment. The script will just do a re-deploy. if the EAR file is not already deployed, then the script will not be able to re-deploy.
       The utility will check if any of the above mentioned files are present, and if found it will apply the units after taking necesary backups
	   DB server units (i.e. objects such as Package,package body, function, procedure, trigger etc) will be backed up in the table cstb_patch_backup. This table and a procedure pr_patch_backup should be pre-compiled in the DB, by running the file patch_backup.ddl
       AP server units (i.e. JS,UIXML,EAR files) will be backed up in the PATCH_BACKUP_LOCATION, under patch sub-directory. The sub-directories will be created by the script
