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
if ! [ -d $EVE_REPO/binary ]; then
	mkdir $EVE_REPO/binary
fi
if ! [ -d $EVE_REPO/stable ]; then
	mkdir $EVE_REPO/stable
fi
if ! [ -d $EVE_REPO/dev ]; then
	mkdir $EVE_REPO/dev
fi
if ! [ -d $EVE_REPO/local ]; then
	mkdir $EVE_REPO/local
fi

export PATH=$EVE_REPO/binary/bin:$EVE_REPO/stable/bin:$EVE_REPO/dev/bin:$EVE_REPO/local/bin:/bin:/usr/bin
export LD_LIBRARY_PATH=
