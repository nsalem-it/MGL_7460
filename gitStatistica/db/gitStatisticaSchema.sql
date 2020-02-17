DROP TABLE detailedGitStatsTbl;
DROP TABLE commitParAnneeParAuteur;
DROP TABLE contributionParFichier;
DROP TABLE implicationTbl;
CREATE TABLE IF NOT EXISTS commitParAnneeParAuteur(contributeur varchr(30),annee int,nombreDeCommit int);
CREATE TABLE IF NOT EXISTS detailedGitStatsTbl(contributeur varchar(100), nombrecommit int, nombrefichierchanger int, nombrelineinserer int,nombrelinesupprimer int,nombrelinechanger int, premiercommit varchar(100),  derniercommit varchar(100));
CREATE TABLE IF NOT EXISTS contributionParFichier(fichier varchar(255), contributeur varchar(50));
CREATE TABLE IF NOT EXISTS implicationTbl(contributeur varchar(50), nombreContribution int, implication int);
.separator ,
.import tempgitstatistica.csv detailedGitStatsTbl
.import tempgitstatistica2.csv contributionParFichier
.import tempgitstatistica3.csv implicationTbl
