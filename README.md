# karuta-csv-processing
Scripts de traitement des csv fourni par les universités à destination des batch Karuta.

La spécification des traitements est décrite dans [specifications_script_traitement_csv](specifications_script_traitement_csv.md)

#### usage :

	./workIn.pl WORKING_DIR
	où WORKING_DIR est le répertoire de travail.

WORKING_DIR doit contenir le fichier *karuta.properties* de paramétrage du script.
Tout fichier, téléchargé ou calculé, serra placé dans ce répertoire.

#### Paramètres dans *karuta.properties*

- log.file: Fichier de log (défaut : WORKING_DIR/karuta.log).

- ftp.addr: Adresse du serveur sftp pour récupérer les fichiers.zip à traiter.
De la forme login@server.name.

- annee.scolaire: année scolaire sur 4 chiffres

- univ.list: liste des universités à traiter; noms courts en minuscules. Désignés ci-dessous par *__nomUniv__*.

- *__nomUniv__*.ftp.rep: nom du repertoire dans ftp de l'université *__nomUniv__*

- *__nomUniv__*.file.prefix: prefix des fichiers de l'université *__nomUniv__*

##### Les paramètres facultatifs
si on ne veut pas récupérer un nouveau .zip mais travailler sur un déjà reçu et dézipé 

- *__nomUniv__*.test.newPath: nom du répertoire déziper en entrée.

le fichier *karuta.data* contient les derniers fichiers traiter pour chaques univ: utile pour faire le calcul des différences.

- *__nomUniv__*.test.oldPath: nom de l'ancien répertoire sur lequel on va se basé pour calculer les différences sans tenir compte du karuta.data


#### Les resultats
Pour chaque université on récupère du sftp le dernier fichier non déjà présent dans WORKING_DIR.
Pour chaque fichier récupéré un fichier.zip est créé dans  WORKING_DIR  prefixé par *_nomUniv_* et terminant par la date.
Il contient les fichiers reçu et les fichiers créés (dans le répertoire *__nomUniv__*_diff).

A la racine de l'archive il y a aussi création d'un fichier de log contenant les lignes en entrées rejetées (non conforme).

#### Contenu des archives resultat ( nomUniv_date.zip)

- le repertoire des données reçu tel quelles  : *__nomUniv__*_*__date__*
- le repertoire avec les fichiers calculés : *__nomUniv__*_*__date__*\_diff
