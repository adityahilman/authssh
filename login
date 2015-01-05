#!/bin/bash
# --- Database Config ---
source /etc/authssh/config_db

# --- LOG File Config ---
LOGFILE='/var/log/authssh-login.log'

# --- Generate Code ---
ssh_code=`tr -dc 0-9 < /dev/urandom | head -c 8`
token_code=`tr -dc a-z < /dev/urandom | head -c 10`
qrencode -o /var/www/html/token/$token_code.png "$ssh_code"

# --- Variable User login ---
get_username=`/usr/bin/whoami`
get_ip=`who am i | awk '{ print $5 }' | tr -d "(" | tr -d ")"`

# --- Set Date USER_LASTLOGIN ---
user_date_login=`date +"%d-%m-%Y %k:%M:%S"`

# --- Function validasi user di MySQL ---
function mysql_check_user() {
	check_user=`mysql -h$DB_HOST -u$DB_USER -p$DB_PASSWORD -e "select USER_NAME from USER where USER_NAME = '$get_username'" $DB_NAME | tail -n1`
}

# --- Function validasi nomor HP di MySQL ---
function mysql_check_phone_number() {
        check_number=`mysql -h$DB_HOST -u$DB_USER -p$DB_PASSWORD -e "select PHONE_NUMBER from USER where USER_NAME = '$get_username'" $DB_NAME | tail -n1`
}


# --- Function untuk MySQL insert ke table USER_LOG
function mysql_insert_user_log() {
	mysql -h$DB_HOST -u$DB_USER -p$DB_PASSWORD -e "insert into USER_LOG (USER_NAME, USER_IP, USER_LASTLOGIN, USER_LOGIN_STATUS) values ('$get_username', '$get_ip', '$user_date_login','$login_status')" $DB_NAME
} 

# --- Function untuk mengirimkan code login dan verifikasi code ---
function send_code() {
	mysql_check_phone_number
	#gammu sendsms TEXT $check_number -text $ssh_code >> /var/log/authssh-gammu.log 2>&1
	#if [ $? -eq 0 ]; then
#		echo "Code sent to $check_number"
#	else
#		echo "Sending code FAILED...!"
#	fi
	echo "Open this link for code http://skripsi/token/$token_code.png"
	echo "Input this code $ssh_code"
	read -t 60 ssh_code_input
	if [ "$ssh_code_input" == "$ssh_code" ]; then
		echo "Code verified $ssh_code"
		echo "$get_username"
		login_status="Success"
		mysql_insert_user_log
		echo "Session opened for $get_username from $get_ip" >> $LOGFILE
		rm -f /var/www/html/token/$token_code.png
		exec -l $SHELL # permit to login using ssh
	else
		echo "Code Failed"
		login_status="Failed"
		mysql_insert_user_log
		echo "Session failed for $get_username from $get_ip" >> $LOGFILE
		rm -f /var/www/html/token/$token_code.png
	fi

}

mysql_check_user
if [ -z $check_user ]; then
	echo "User is not registered"
	exit 1
else
	send_code
fi
