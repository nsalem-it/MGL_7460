#!/usr/bin/env bash
# date de debut git
_since=${_GIT_SINCE:-}
[[ -n "${_since}" ]] && _since="--since=$_since"
# date de fin de git
_until=${_GIT_UNTIL:-}
[[ -n "${_until}" ]] && _until="--until=$_until"
# definir le fichier et les repertoir a exclure des stat
_pathspec=${_GIT_PATHSPEC:-}
[[ -n "${_pathspec}" ]] && _pathspec="-- $_pathspec"
# configurer la vue des merge par default show no merge commits
# Exclusive : montre seuelment les merges
# Enable shows regular commits together with normal commits
_merges=${_GIT_MERGE_VIEW:-}
if [[ "${_merges,,}" == "exclusive" ]]; then 
    _merges="--merges"
elif [[ "${_merges,,}" == "enable" ]]; then
    _merges=""
else
    _merges="--no-merges"
fi

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
                rm temp.csv
	        
}
# obtenir la liste de contributeur
contributeur(){
  git shortlog -sn --all
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

# statistique des action de modification de fichier par auteur
# statistique détailler du git 
function detailedGitStats() {

 # Prompt message
   git -c log.showSignature=false log  --use-mailmap --date=format:'%Y-%m-%d' $_merges --numstat  \
        --pretty="format:commit %H%nAuthor: %aN <%aE>%nDate:   %ad%n%n%w(0,4,4)%B%n" \
        $_since $_until $_pathspec | LC_ALL=C awk '
        /^Author:/ {
        $1 = ""
        author = $0
        commits[author] += 1
        commits["total"] += 1
        }
        /^Date:/ {
        $1="";
        first[author] = substr($0, 2)
        if(last[author] == "" ) { last[author] = first[author] }
        }
        /^[0-9]/ {
        more[author] += $1
        less[author] += $2
        file[author] += 1
        more["total"]  += $1
        less["total"]  += $2
        file["total"]  += 1
        }
        END {
        for (author in commits) {
            if (author != "total") {
            {printf "%s,%s,%s,%s,%s,%s,%s,%s\n",author,commits[author], file[author] ,more[author]  ,less[author], more[author]+less[author] , first[author], last[author]}
            }
        }
        }' >> $DIR/db/temp.csv     
}

 
detailedGitStats
init
nombreCommitParAnneeParAuteur