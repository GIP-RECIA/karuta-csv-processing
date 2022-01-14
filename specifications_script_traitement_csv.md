## Détail des fichiers en entrée

Il y a actuellement 2 comptes SFTP, d'autres sont a prévoir:

* univ.tours
* univ.orleans

Chaque compte dépose à son rythme des archives (tous les jours à terme) nommées sous ce format: {{universite}}_{{date_iso}}.zip, chacune contenant 3 types de fichiers en entrée + leur md5 sous le même format de nommage :

* univ-Orleans_20211118_STAFF.csv
* univ-Orleans_20211118_ETU.csv
* univ-Orleans_20211118_FORMATIONS.csv

Formalisme (liste des colonnes) des fichiers csv:

* ETU:

  ```
  "eppn","nomFamilleEtudiant","prenomEtudiant","courrielEtudiant","matriculeEtudiant","codesEtape"
  
  
  
  
  
  ```
* STAFF:

  ```
  "eppn","nomFamilleEnseignant","prenomEnseignant","courrielEnseignant","codesEtape"
  
  
  
  
  
  ```
* FORMATION:

  ```
  "codeEtape","libelleEtape","libelleCourt"
  
  
  
  
  
  ```

l'attribut "codesEtape" est multivalué avec comme caractère séparateur des valeurs le "@"

D'autres attributs pourront être fourni, mais il ne seront pas a traiter dans cette première version du script.

## V1 du script

#### Pour la première version du script, voici les fichiers à générer:

* 1 fichier csv par valeur "codesetape" à partir du fichier ETU, permettant "d'exploser" la génération des portfolios par codeEtape pour les étudiants selon ces entêtes:

  ```
  “model_code”,”dossierModeles”,”cohorte”,
  “kapc/etudiants/modeles.batch-creer-etudiants”,”${diplôme}${univ}kapc/etudiants/modeles”,”${diplôme}${univ}kapc/etudiants/instances/${cohorte}_${année}”
  “eppn”,”nomFamilleEtudiant”,”prenomEtudiant”,”courrielEtudiant”,”matriculeEtudiant”,
  # lignes désignant les comptes appartenant à la cohorte
  
  
  
  
  
  
  ```
* 1 fichier csv par valeur "codesetape" à partir du fichier STAFF, permettant "d'exploser" la génération des portfolios par codeEtape pour les enseignants selon ces entêtes:

  ```
  “model_code”,”dossierModeles”,”instancesEnseignants”,
  “kapc/enseignants/modeles.batch-creer-enseignants”,”${diplôme}${univ}kapc/enseignants/modeles”,”${diplôme}${univ}kapc/enseignants/instances/${cohorte}”,
  “eppn”,”nomFamilleEnseignant”,”prenomEnseignant”,”courrielEnseignant”,
  # lignes désignant les comptes appartenant à la cohorte
  
  
  
  
  
  
  
  ```
* pour les variables indiquées dans les fichiers sous forme du pattern ${var} voici les détails (il ne doit y avoir que des caractères et chiffres [A-Z0-9]+, aucun espace ni signe):
  * *cohorte* est l'acronyme qu'on retrouve dans le fichier FORMATIONS dans une 3ème colonne "libelleCourtEtape". Ce champs est à utilisé transformé de la façon suivante: remplacement des caractères non alphanumériques par le caractère `_` en supprimant les redondances successives de ce caractère (il ne peut y avoir qu'un seul `_` entre chaque caractères alphanumériques.
  * *diplôme*, correspond au premier mot obtenu par split sur le caractère espace du champ "libelleEtape" du fichier FORMATIONS. Ce terme est à transformer en minuscules. (en attendant mieux)
  * *univ* est le nom court de l'université, soit: `tours`, `blois`, `orleans`, ces termes sont en minuscules.
  * *année*, correspond pour le moment à l'année scolaire 2021, on reverra cela après si on peut traiter correctement ou non à partir d'un des futurs champs afin de connaître uniquement la promotion du diplôme (2021 pour un première année, et 2020 pour un deuxième année par exemple)
* des ";" peuvent être utilisés à la place des virgules comme séparateurs de champs, le parser Karuta sait traiter. Comme le fait d'avoir une virgule en fin de ligne cela ne semble pas obligatoire.
* Il n'y a pas de règle de nommage pour les fichiers à générer, cependant il faut que ce soit lisible pour nous, donc je propose un nommage du type

  ```
   {univ}_{diplôme}_{typePersonne}_{cohorte}_{année}_{date_ISO}.csv
  
  
  
  
  ```

#### Gestion des différentiels entre deux entrants pour une même univ à des dates différentes:

* Pour les ajouts il faut générer un fichier à l'identique de ce qui a été spécifié.
* Pour les suppressions il faut générer un fichier spécifique afin de faire les suppressions manuellement
* Pour les modifications pour le moment il ressortir dans un nouveau fichier les lignes ayant changé, le traitement sera manuel, nous ne savons pas encore spécifier.

#### Dépôt des fichiers:

Les fichiers seront à déposer sur le serveur epf-karuta1 dans un dossier nommé à la date de génération et sur un chemin paramétrable. Adrien devra avoir accès à cet espace.