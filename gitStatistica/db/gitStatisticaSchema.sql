DROP TABLE gitChangeByAuthor;
DROP TABLE commitParAnneeParAuteur;
CREATE TABLE IF NOT EXISTS gitChangeByAuthor(contributeur varchar(30), nombrecommit int, nombrefichierchanger int, nombrelineinserer int,nombrelinesupprimer int, diffenterajoutetsupp int, ratioentresuppetajout int);
CREATE TABLE IF NOT EXISTS commitParAnneeParAuteur(contributeur varchr(30),annee int,nombreDeCommit int);