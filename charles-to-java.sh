#!/bin/bash -e
[[ -z "$1" ]] && echo '$1: auto find security/cacerts in $1' && exit 1

myalias=charles
mycharlespem=$HOME/.charles/ca/charles-proxy-ssl-proxying-certificate.pem
[[ ! -f "$mycharlespem" ]] && echo "charles root pem miss: $mycharlespem" && exit 1
mysha256=$(openssl x509 -fingerprint -sha256 -noout -in $mycharlespem)
mysha256="${mysha256#*=}"
echo -e "charles finger SHA-256\n  $mysha256"

mytarget=$1

eclipseini=$(ls "$mytarget"/*clipse.ini 2>/dev/null || echo "")
if [ -n "$eclipseini" ]; then
	echo -e "\neclipse\n  $eclipseini"
	myjava=$(grep -A 1 "^-vm$" "$eclipseini"| tail -n 1)
	echo -e "  -vm\n    $myjava"
	myjavahome="${myjava%/bin/java*}"
	[[ $myjavahome != /* ]] && myjavahome=$(dirname $eclipseini)/$myjavahome
	mytarget="$myjavahome"
else
	myjavahome=$(find "$mytarget" -path "*/bin/java" | head -n 1)
fi
mykeytool=$myjavahome/bin/keytool
echo -e "\nJAVA_HOME\n  $myjavahome"

function doImp() {
	local cacerts=$1
	local found=$($mykeytool -keystore "$cacerts" -storepass changeit -list -v 2>/dev/null | grep $mysha256)
	echo -e "cacerts\n  $cacerts"
	if [ -n "$found" ]; then
		echo -e "  exist ${found#* }"
	else
		echo -e "\n  import -alias $myalias -file $mycharlespem"
		$mykeytool -keystore "$cacerts" -storepass changeit \
			-import -trustcacerts -alias "$myalias" -file "$mycharlespem" -noprompt 2>/dev/null
	fi
	echo "-->"
	$mykeytool -keystore "$cacerts" -storepass changeit -list -v 2>/dev/null | grep -B10 $mysha256
	echo "<--"
}
echo -e "\nfind security/cacerts\n  $mytarget\n"
for loc in $(find "$mytarget" -path "*/security/cacerts"); do
	doImp $loc
done
