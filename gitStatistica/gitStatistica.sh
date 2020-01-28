#!/usr/bin/env bash

if [ -L $0 ] ; then
	    DIR=$(dirname $(readlink -f $0)) 
    else
	    DIR=$(dirname $0) 
fi 
FILE="$DIR/db/gitStatisticaDB.sqlite"
#initialisation de la base de donnees
init(){
			echo "Creation de la base de donnees"
		        sqlite3 "$FILE" < "$DIR/db/gitStatisticaSchema.sql"
	        
}
# obtenir la liste de contributeur
contributeur(){
  git shortlog -sn --all
}

# statistique des action de modification de fichier par auteur
statAuthorAction(){
        
	users=$(git shortlog -sn --no-merges | awk '{printf "%s %s\n", $2, $3}')
	IFS=$'\n'
	for userName in $users
    		do
      		 gitcommande=$(git log --shortstat --author="$userName" | grep -E "fil(e|es) changed" | awk '{files+=$1; inserted+=$4; deleted+=$6; delta+=$4-$6; ratio=deleted/inserted} END {printf "%s\n%s\n%s\n%s\n%s\n",files, inserted, deleted, delta, ratio }') 

      		 ary=($gitcommande)
      		 nbrCommit=$(git shortlog -sn --no-merges  --author="$userName" | awk '{print $1}')
      		 sqlite3 "$FILE" "INSERT INTO gitChangeByAuthor values('$userName','$nbrCommit',${ary[0]},${ary[1]},${ary[2]},${ary[3]},${ary[4]});"
    		done

}

# Contribution par nom de fichier ou extension
contributionParFichier(){

	FILENAME=$1
	if [ ! -f $FILENAME ]
		then
			echo "Expecting a single file as argument"
			exit 1
	fi
	git log --pretty=format:"%an" $FILENAME \
		 | sort | uniq \
	 	 | xargs -I '{}' echo "$FILENAME,{}"

}

# statistique de commit par année et par auteur
nombreCommitParAnneeParAuteur(){
        users=$(git shortlog -sn --no-merges | awk '{printf "%s %s\n", $2, $3}')
	IFS=$'\n'
	for userName in $users
	     do
		gitCmdYear=$(git log --pretty='format:%cd' --date=format:'%Y' --author "$userName"| uniq -c | awk '{printf "%s\n",$2}')
		aryYear=($gitCmdYear)
		gitCmdCommit=$(git log --pretty='format:%cd' --date=format:'%Y' --author "$userName"| uniq -c | awk '{printf "%s\n",$1}')
		aryCommit=($gitCmdCommit)
		for index in ${!aryYear[*]}
		do
		  sqlite3 "$FILE" "INSERT INTO commitParAnneeParAuteur values('$userName',${aryYear[$index]},${aryCommit[$index]});"
	        done
	     done

}

init 
statAuthorAction 
nombreCommitParAnneeParAuteur
