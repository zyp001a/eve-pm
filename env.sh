if [ -z $1 ]; then
	export EVE_HOME=$PWD;
else
	export EVE_HOME=$1
fi
echo "use $EVE_HOME as EVE_HOME";

if [ -z $2 ]; then
	export EVE_REPO=$EVE_HOME/../eve-repo
else
	export EVE_REPO=$2
fi
echo "use $EVE_REPO as EVE_REPO"
if ! [ -d $EVE_REPO ]; then
	mkdir $EVE_REPO
fi


