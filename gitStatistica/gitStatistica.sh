#!/usr/bin/env bash

## ----------------------------------
# Step #1: Define variables
# ----------------------------------
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
# Exclusive : montre seulement les merges
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
# Limit git log output
## par default 30 jours
_limit=${_GIT_LIMIT:-}
if [[ -n "${_limit}" ]]; then 
    _limit=$_limit
else
    _limit=30
fi

FILE="$DIR/db/gitStatisticaDB.sqlite"
EDITOR=vim
PASSWD=/etc/passwd
RED='\033[0;41;30m'
STD='\033[0;0;39m'
##-----------------------------------------------------------------------
#initialisation de la base de donnees
##-----------------------------------------------------------------------
function init(){
			echo "Creation de la base de donnees"
		        sqlite3 "$FILE" < "$DIR/db/gitStatisticaSchema.sql"
                rm temp.csv
	        
}

# ----------------------------------
#  User defined function
# ----------------------------------
pause(){
   read -p "Press [Enter] key to continue..." fackEnterKey
  }
#------------------------------------------------------------------------  
# fonction pour calculer implication developpeur dans un repo ou fichier
#-------------------------------------------------------------------------
implication(){
	 echo "one() called"
         USERNAME=$1
         INDEX=${2:-list_contrib.csv}
         T=$(cat $INDEX | wc -l | tr -d ' ')
         C=$(cat $INDEX | grep ",${USERNAME}$" | wc -l | tr -d ' ')
        RESULT=$(echo "scale=5; ($C / $T) * 100" | bc)
        printf "%s,%d,%.2f\n" "$USERNAME" "$C" "$RESULT"
 }

AfficherContributeur(){
FILENAME=$1
if [ ! -f $FILENAME ]
then
	echo "Expecting a single file as argument"
        exit 1
fi
	git log --pretty=format:"%an" $FILENAME | sort | uniq | xargs -I '{}' echo "$FILENAME,{}"
	pause
 }

##-----------------------------------------------------------------------
# Contribution par nom de fichier ou extension
##-----------------------------------------------------------------------
function contributionParFichier(){

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

##-----------------------------------------------------------------------
# statistique de commit par année et par auteur
##-----------------------------------------------------------------------
function exportNombreCommitParAnneeParAuteur(){
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

    echo "Fin extraction et export des donnes ver sqlite ... Enjoy"
}


##-----------------------------------------------------------------------
# statistique des action de modification de fichier par auteur
# statistique détailler du git
##----------------------------------------------------------------------- 
function exportDetailedGitStats() {

    echo "Debut de l'export des donnees details pour le repo..."
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
        }' >> temp.csv 
	
	echo "Initialisation de la base de donnee et export des details ..." $(init)	 
	echo "Debut d'export des nombre commit par annee par contributeur ..." $(exportNombreCommitParAnneeParAuteur) 

	pause

}
##-----------------------------------------------------------------------
## Function qui retourne les  commits par mois 
##-----------------------------------------------------------------------
function commitParMois() {
    echo -e "\tmonth\tsum"
    for i in Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec
    do
        echo -en "\t$i\t"
        git -c log.showSignature=false shortlog -n $_merges --format='%ad %s' \
            $_since $_until | grep " $i " | wc -l
    done | awk '{ 
        count[$1] = $2 
        total += $2 
    } 
    END{ 
        for (month in count) {
            s="|";
            if (total > 0) {
                percent = ((count[month] / total) * 100) / 1.25;
                for (i = 1; i <= percent; ++i) {
                    s=s"█"
                }
                printf( "\t%s\t%-0s\t%s\n", month, count[month], s );
            }
        }
    }' | LC_TIME="en_EN.UTF-8" sort -M

	pause
}
##-----------------------------------------------------------------------
## Fonction qui retourne les chagement dans les log sous forme lisible
## accept parametre NOM d'auteur par default tous les auteurs
##------------------------------------------------------------------------
function logsDesChangement() {
    local author="${1:-}"
    local _author=""
    local next=$(date +%F)

    if [[ -z "${author}" ]]; then
        _author="--author=**"
    else

        _author="--author=${author}"
    fi

    git -c log.showSignature=false log \
        --use-mailmap \
        $_merges \
        --format="%cd" \
        --date=short "${_author}" $_since $_until $_pathspec \
        | sort -u -r | head -n $_limit \
        | while read DATE; do
              echo -e "\n[$DATE]"
              GIT_PAGER=cat git -c log.showSignature=false log \
                                --use-mailmap $_merges \
                                --format=" * %s (%aN)" "${_author}" \
                                --since=$DATE --until=$next
              next=$DATE
          done
	pause
}

##------------------------------------------------------------
## fonction pour afficher les merges dans toutes les branches
##---------------------------------------------------------------
mergeStatistique(){

 echo "% of Total Merges               Author  # of Merges  % of Commits"

 mergeCounts=`git log --first-parent --merges --pretty='format:%an' | sort | uniq -c | sort -nr`
 totalMerges=`git log --first-parent --merges --oneline | wc -l`
 if [ $totalMerges -eq 0 ]; then 
	 echo 'No merges found.'
         exit 0
 fi
 while read -r line; do
 authorMerges=`awk '{print $1}' <<< "$line"`
 author=`sed "s/$authorMerges //" <<< "$line"`
 authorCommits=`git log --oneline --author="$author" | wc -l`
 totalPercentage=`echo "scale=2; (100*$authorMerges) / $totalMerges" | bc`
 authorPercentage=`echo "scale=2; (100*$authorMerges) / $authorCommits" | bc`
 printf "%17.2f %20s %12i %13.2f\n" "$totalPercentage" "$author" "$authorMerges" "$authorPercentage"																						      
 done <<< "$mergeCounts"

 pause
}

# function to display menus
show_menus() {
		clear
		echo "**************************************"	
		echo " M E N U - G I T  S T A T I S T I C A"
		echo "**************************************"
		echo "1. Afficher les Contributeurs"
		echo "2. Afficher les statistiques des merges"
		echo "3. Afficher les changement dans repo Git les 30 dernier jours"
		echo "4. Afficher les commit par mois"
		echo "5. Export detail du logs vers sqlite table"
		echo "6. Exit"
	}

# read input from the keyboard and take a action
# invoke the one() when the user select 1 from the menu option.
# invoke the two() when the user select 2 from the menu option.
# Exit when user the user select 3 form the menu option.
read_options(){
		local choice
	        read -p "Enter choice [ 1 - 6] " choice
		case $choice in
		1) AfficherContributeur ;;
		2) mergeStatistique ;;
		3) logsDesChangement ;; 
		4) commitParMois ;;
		5) exportDetailedGitStats ;;
		6) exit 0;;
		*) echo -e "${RED}Error...${STD}" && sleep 2
		esac
}
# ----------------------------------------------
# Step #3: Trap CTRL+C, CTRL+Z and quit singles
# ----------------------------------------------
trap '' SIGINT SIGQUIT SIGTSTP
 
# -----------------------------------
# Step #4: Main logic - infinite loop
# ------------------------------------
while true
do
	 
   show_menus
   read_options
done
