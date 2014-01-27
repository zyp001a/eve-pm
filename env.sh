if [ -z $1 ]; then
	export EVE_HOME=$PWD
fi
export EVE_HOME=$1
export EVE_REPO=$2
mkdir $EVE_REPO/stable
mkdir $EVE_REPO/dev
mkdir $EVE_REPO/local

export PATH=$EVE_REPO/stable/bin:$EVE_REPO/dev/bin:$EVE_REPO/local/bin:/bin:/usr/bin
export LD_LIBRARY_PATH=
