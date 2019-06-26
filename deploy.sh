#!/bin/bash

validateWLSConn() {
echo ----------------------------------------------------------------------------------------------
echo Checking Weblogic Connection...
echo ----------------------------------------------------------------------------------------------
$wlst << EOF
l_exit = 0
try :
    connect('${WLS_USERNAME}', os.environ['WLS_PASSWORD'], '${WLS_URL}')
except Exception,e:
    print e
    print 'Error in connecting'
    l_exit = 1

exit(exitcode=l_exit)
EOF

l_rc=$?
if [ ${l_rc} -ne 0 ]; then
               echo "WLS Connection check failed"
               exit ${l_rc}
fi

echo ----------------------------------------------------------------------------------------------
echo Weblogic Connection is Success
echo ----------------------------------------------------------------------------------------------
}

applyEAR() {
echo Applying EAR $1 $2
$wlst << EOF
#!/usr/bin/python

import sys
import os.path
import shutil
import datetime

args = sys.argv[1:]

l_ear_path = ''
l_dt_time = datetime.datetime.now()

connect('${WLS_USERNAME}', os.environ['WLS_PASSWORD'], '${WLS_URL}')

apps = cmo.getAppDeployments()
for app in apps:
        cd('/AppDeployments/'+app.getName())
        l_ear_path = get('AbsoluteSourcePath')
        if os.path.basename(l_ear_path) == os.path.basename('$1'):
                print 'Backing up ' + l_ear_path + ' to ' + '${PATCH_BACKUP_LOCATION}' + '/$2/EAR'
                shutil.copy(l_ear_path, '${PATCH_BACKUP_LOCATION}'+'/$2/EAR')
                print 'Done backing up ear file ' + l_ear_path
                edit()
                startEdit()
                stopApplication(app.getApplicationName())
                print 'Copying $1  to ' + l_ear_path
                shutil.copy('$1',l_ear_path)
                redeploy(app.getApplicationName())
                cd('/AppDeployments/'+app.getName())
                print 'Setting Notes: Updated Patch $2  at '+ str(l_dt_time)
                set('Notes', 'Patch $2 deployed at '+ str(l_dt_time))
                save()
                activate(block='true')
                startApplication(app.getApplicationName())
                print 'Finished Redeploying ' + app.getApplicationName()
                break

print 'Finished Deploying $1'
disconnect()
exit()

EOF
}

validateDBConn() {
echo ----------------------------------------------------------------------------------------------
echo Checking DB Connection...
echo ----------------------------------------------------------------------------------------------

echo "Oracle Home " $ORACLE_HOME

sqlplus $DBCONN << EOF
prompt Connected to DB
exit;
EOF

l_rc=$?
if [ ${l_rc} -ne 0 ]; then
        echo "DB Connection check failed"
        exit ${l_rc}
fi
echo ----------------------------------------------------------------------------------------------
echo DB Connection is Success
echo ----------------------------------------------------------------------------------------------
}

createPatchSQLFile() {
echo "prompt Applying DB units in the order "${DB_FILE_ORDER}                            > ${l_patch_file}.sql
echo ""                                                                                  >> ${l_patch_file}.sql

for i in ${DB_FILE_ORDER}
do
   find ${l_patch_loc} -iname *.$i -type f                                           \
       | awk                                                                         \
           -v l_patch_no="${l_patch_no}"                                             \
           -F/                                                                       \
           '{print                                                                   \
               "prompt Backing up " $NF                                      "\n"    \
               "exec pr_patch_backup(\047"l_patch_no"\047,\047"$NF"\047);"   "\n"    \
               "prompt compiling " $0 "..."                                  "\n"    \
               "@" $0                                                        "\n\n"  \
           }'                                                                            >> ${l_patch_file}.sql
done

echo "exit"                                                                              >> ${l_patch_file}.sql
}

createPatchSHFile() {
echo "echo Applying Ap server units..."                                                  > ${l_patch_file}.sh

echo ""                                                                                  >> ${l_patch_file}.sh
echo "echo Applying UIXML files..."                                                      >> ${l_patch_file}.sh
echo ""                                                                                  >> ${l_patch_file}.sh

for i in ${UIXML_LANG}
do
  echo "mkdir -p ${PATCH_BACKUP_LOCATION}/${l_patch_no}/UIXML/$i"                        >> ${l_patch_file}.sh
  echo ""                                                                                >> ${l_patch_file}.sh
  find ${l_patch_loc} -path "*/$i/*" -iname *.XML -type f                           \
      |awk                                                                          \
          -v l_bkp_loc="${PATCH_BACKUP_LOCATION}/${l_patch_no}/UIXML/$i/"           \
          -v l_uixml_loc="${UIXML_LOCATION}/$i/"                                    \
          -F/                                                                       \
          '{print                                                                   \
              "echo Backing up " $NF                                        "\n"    \
              "cp -f " l_uixml_loc$NF " " l_bkp_loc                         "\n"    \
              "echo Copying file " $0                                       "\n"    \
              "cp -f " $0 " " l_uixml_loc                                   "\n\n"  \
          }'                                                                        \    >> ${l_patch_file}.sh
done

echo ""                                                                                  >> ${l_patch_file}.sh
echo "echo Applying JS files..."                                                         >> ${l_patch_file}.sh
echo ""                                                                                  >> ${l_patch_file}.sh

echo "mkdir -p ${PATCH_BACKUP_LOCATION}/${l_patch_no}/JS"                                >> ${l_patch_file}.sh
echo ""                                                                                  >> ${l_patch_file}.sh
find ${l_patch_loc} -iname *.js -type f                                             \
        |awk                                                                        \
            -v l_bkp_loc="${PATCH_BACKUP_LOCATION}/${l_patch_no}/JS/"               \
            -v l_js_loc="${JS_LOCATION}/"                                           \
            -F/                                                                     \
            '{print                                                                 \
                "echo Backing up " $NF                                       "\n"   \
                "cp -f " l_js_loc$NF " " l_bkp_loc                           "\n"   \
                "echo Copying file " $0                                      "\n"   \
                "cp -f " $0 " " l_js_loc                                     "\n\n" \
            }'                                                                           >> ${l_patch_file}.sh

echo ""                                                                                  >> ${l_patch_file}.sh
echo "echo Removing SYS JS files..."                                                     >> ${l_patch_file}.sh
echo "rm -f ${JS_LOCATION}/SYS/*SYS.js"                                                  >> ${l_patch_file}.sh
echo ""                                                                                  >> ${l_patch_file}.sh

echo ""                                                                                  >> ${l_patch_file}.sh
echo "echo Applying EAR files..."                                                        >> ${l_patch_file}.sh
echo ""                                                                                  >> ${l_patch_file}.sh

echo "mkdir -p ${PATCH_BACKUP_LOCATION}/${l_patch_no}/EAR"                               >> ${l_patch_file}.sh
echo ""                                                                                  >> ${l_patch_file}.sh
find ${l_patch_loc} -iname *.ear -type f                                            \
        |awk                                                                        \
            -v l_patch_no="${l_patch_no}"                                           \
            -v l_patch_file="${l_patch_file}.py"                                    \
            '{print                                                                 \
                 "echo Applying file " $0                                    "\n"   \
                  "applyEAR " $0 " " l_patch_no                              "\n\n" \
            }'                                                                          >> ${l_patch_file}.sh
}

deployPatch() {


echo ----------------------------------------------------------------------------------------------
echo Starting Deploy script...
echo ----------------------------------------------------------------------------------------------
echo "Patch Location  = " ${l_patch_loc}
l_patch_no=$(basename -- "${l_patch_loc}")
l_patch_file=/tmp/patch_file_${l_patch_no}
echo ----------------------------------------------------------------------------------------------
echo Patch Number         = ${l_patch_no}
echo Patch Scripts File   = ${l_patch_file}
echo ----------------------------------------------------------------------------------------------	


validateWLSConn
validateDBConn
createPatchSQLFile
createPatchSHFile

echo ----------------------------------------------------------------------------------------------
echo Going to Apply DB file ${l_patch_file}.sql
echo ----------------------------------------------------------------------------------------------

sqlplus ${DBCONN} @${l_patch_file}.sql 

echo ----------------------------------------------------------------------------------------------
echo Going to Apply AP file ${l_patch_file}.sh
echo ----------------------------------------------------------------------------------------------

source ${l_patch_file}.sh

echo All done...

}

#--------------------------Main Script Starts here--------------------------------------------------

if [ "$#" -ne 2 ]; then
  echo "Usage: ${BASH_SOURCE[0]} [properties_file] [patch_location]"
  exit 1
fi

if [ ! -e "$1" ]; then
    echo "Property file $1 does not exist. Aborting execution..."
    exit 1
fi

l_patch_loc=$2

if [ ! -d "${l_patch_loc}" ]; then
    echo "Patch Location ${l_patch_loc} does not exist. Aborting execution..."
    exit 1
fi

source $1
l_log_file=${PATCH_LOG_LOCATION}/$(basename -- "$2")"_"`date +%d-%m-%y-%H%M%S`".log"

echo "Logs will be written to file ${l_log_file}"

deployPatch | awk '{ print strftime("%Y-%m-%d %H:%M:%S : "), $0; fflush(); }' | tee ${l_log_file}
