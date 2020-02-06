DROP TABLE detailedGitStatsTbl;
DROP TABLE commitParAnneeParAuteur;
CREATE TABLE IF NOT EXISTS commitParAnneeParAuteur(contributeur varchr(30),annee int,nombreDeCommit int);
CREATE TABLE IF NOT EXISTS detailedGitStatsTbl(contributeur varchar(100), nombrecommit int, nombrefichierchanger int, nombrelineinserer int,nombrelinesupprimer int,nombrelinechanger int, premiercommit varchar(100),  derniercommit varchar(100));
.separator ,
.import temp.csv detailedGitStatsTbl
