# karuta-csv-processing
Scripts de traitement des csv fourni par les universités à destination des batch Karuta.

La spécification des traitements est décrite dans [specifications_script_traitement_csv](specifications_script_traitement_csv.md)

#### usage :

	./workIn.pl WORKING_DIR
	ou WORKING_DIR est le répertoire de travail.

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

#### Les resultats
Pour chaque université on récupère du sftp le dernier fichier non déjà présent dans WORKING_DIR.
Pour chaque fichier récupéré un fichier.zip est créé dans  WORKING_DIR  prefixé par *_nomUniv_* et terminant par la date.
Il contient les fichiers reçu et les fichiers créés (dans le répertoire *__nomUniv__*_tmp).

A la racine de l'archive il y a aussi création d'un fichier de log contenant les lignes en entrées rejetées (non conforme).
