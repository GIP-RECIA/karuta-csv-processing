## Détail des fichiers en entrée (Tours, Orléans, INSA)

Il y a actuellement 2 comptes SFTP, d'autres sont a prévoir:

* univ.tours
* univ.orleans
* insa.cvl (en cours)

Chaque compte dépose à son rythme des archives (tous les jours à terme) nommées sous ce format: `{{universite}}_{{date_iso}}.zip`, chacune contenant 4 types de fichiers + leur md5 sous le même format de nommage :

* `univ-Orleans_20211118_STAFF.csv`listant les utilisateurs avec le rôle enseignant,
* `univ-Orleans_20211118_ETU.csv `listant les utilisateurs avec le rôle étudiant,
* `univ-Orleans_20211118_FORMATIONS.csv` listant les formations,
* `univ-Orleans_20211118_SUPERVISEUR.csv` listant les utilisateurs autres ayant un rôle de superviseur.

Formalisme (liste des colonnes) des fichiers csv:

* ETU:

  ```
  "eppn","nomFamilleEtudiant","prenomEtudiant","courrielEtudiant","matriculeEtudiant","codesEtape"
  
  
  
  ```
* STAFF:

  ```
  "eppn","nomFamilleEnseignant","prenomEnseignant","courrielEnseignant","codesEtape"
    
  
  
  ```
* FORMATIONS: 

  version ancienne

  ```
  "codeEtape","libelleEtape","libelleCourtEtape","site"
  
  
  
  ```

  nouvelle version

  ```
  "codeEtape","libelleEtape","typeFormation", "sigleFormation","parcoursFormation","anneeFormation","site"
  
  
  
  ```

  Le champs typeFormation correspondra à type court de formation, par exemple "BUT", "LICENCE", "MASTER",  "INGÉNIEUR", etc...

  Le champs sigleFormation devra être (du moins essayer de se rapprocher) d'un sigle pour l'intitulé de la formation (texte très court généralement utilisé dans le langage courant), par exemple: "GEII", "INFORMATIQUE", "GEA", "QLIO", "GMP", "MTE", etc...

  Le champs parcoursFormation est optionnel, il permet de façon succincte de définir le parcours ou plus communément l'option de la formation. Cela permettra de définir et de distinguer des compétences/SAÉ spécifiques par rapport à une formation commune.

  Le champs anneeFormation permet de définir l'année de la formation, attention ce n'est pas l'année (bac +x) dans le parcours de l'étudiant, mais par exemple 2 pour un Master en 2ème année et non 5 pour ce cas. Devra être limité à un chiffre.
* SUPERVISEUR:

  ```
  "eppn","nomFamilleSuperviseur","prenomSuperviseur","courrielSuperviseur"
  
  
  
  ```
* l'attribut "codesEtape" est multivalué avec comme caractère séparateur des valeurs le caractère "@"

D'autres attributs pourront être fourni, mais il ne seront pas a traiter dans cette version du script.

## Scripts de traitement des données csv transmises par les établissements (GIP RECIA)

### Scripts lié à KAPC1.2

* 1 fichier csv pour toutes les formations selon ces entêtes et un exemples de valeurs formalisée:

  ```
  ”formation_code”,”formation_label”
  ”${univ}_${site}_${formation_code}”,”${univ}_${site} - ${formation_label}”
  
  
  
  
  
  
  
  
  
  
  ```

  Fichier nommé avec le pattern: `{univ}_FORMATIONS_{date_ISO}.csv`
* 1 fichier csv par valeur "codesetape" à partir du fichier ETU, permettant "d'exploser" la génération des portfolios par codeEtape pour les étudiants selon ces entêtes:

  ```
  “model_code”,”formation_code”,”formation_label”,”cohorte”,
  “kapc/8etudiants.batch-creer-etudiants-authentification-externe”,”${univ}_${site}_${formation_code}”,”${univ}_${site} - ${formation_label}”,”${univ}_${site}_${cohorte}”
  “nomFamilleEtudiant”,”prenomEtudiant”,”courrielEtudiant”,”matriculeEtudiant”,”loginEtudiant”
  # lignes désignant les comptes appartenant à la cohorte (et du site) - "loginEtudiant" doit être l'eppn
  
  
  
  
  
  
  
  
  
  
  ```

  Fichier nommé selon le pattern: `{univ}_ETU_{site}_{cohorte}_{année}_{dateISO}.csv`

  Nommer les fichiers avec la notion de site n'est utile que pour le lecteur, car à chaque cohorte correspond un site précis, on ne peut pas avoir un même nom de cohorte pour des sites différents.
* 1 fichier csv par valeur "codesetape" à partir du fichier STAFF, permettant "d'exploser" la génération des portfolios par codeEtape pour les enseignants selon ces entêtes:

  ```
  “model_code”,”formation_code”,”formation_label”
  “kapc/3enseignants.batch-creer-enseignants-authentification-externe”,”${univ}_${site}_${formation_code}”,”${univ}_${site} - ${formation_label}”,
  ”nomFamilleEnseignant”,”prenomEnseignant”,”courrielEnseignant”,”loginEnseignant”
  # lignes désignant les comptes appartenant à la formation - "loginEnseignant" doit être l'eppn
  
  
  
  
  
  
  
  
  
  
  ```

  ATTENTION: la subtilité étant que plusieurs codes étapes peuvent correspondre à une même Formation. Il faudra donc rassembler tous les STAFF de la même univ - formation, même si le code étape change.

  Fichier nommé selon le pattern: `{univ}_STAFF_{site}_{formation_code}_{année}_{dateISO}.csv`
* 1 fichier csv par univ à partir du fichier INGE_PEDA, pour les personnels encadrants selon ces entêtes:

  ```
  à déterminer
  
  
  
  
  
  
  
  
  
  ```
* pour les variables indiquées dans les fichiers sous forme du pattern `${var}` voici les détails (sauf exception explicité il ne doit y avoir que des caractères et chiffres [A-Z0-9]+, aucun espace ni signe):
  * *cohorte* est l'acronyme qu'on retrouve dans le fichier FORMATIONS dans une 3ème colonne `libelleCourtEtape`. Ce champs est à utilisé transformé de la façon suivante: remplacement des caractères non alphanumériques par le caractère `_` en supprimant les redondances successives de ce caractère (il ne peut y avoir qu'un seul `_` entre chaque caractères alphanumériques).
  * *formation_code* peut être obtenu à partir de la variable *cohorte* en supprimant le caractère numérique entre "_" (sans caractère alphabétique autour) ainsi que les redondances successives du caractères `_`. Pour l'INSA on supprime la chaine décimale avec le caractère `_` devant une chaîne décimale et si c'est en fin de chaîne. La chaîne ne doit contenir que des caractères en majuscule sans ponctuation.
  * *formation_label* est à déterminer à partir de la colonne `libelleEtape` en supprimant la chaine `ANNÉE\s\d` où `\d` correspond à une chaîne numérique et `\s` à un espace, en supprimant les caractères numériques et en simplifiant les espaces successifs. La chaîne ne doit contenir que des caractères en majuscule, la ponctuation est autorisée.
  * *univ* est le nom court de l'université en majuscule, soit: `TOURS`, `ORLEANS`,`INSA`, etc... ces termes sont en minuscules.
  * *site* correspondant à la structure/antenne, soit `IUT-18`, `IUT-28`, `IUT-36-CHX`, etc... obtenu via la colonne `site` dans le fichier FORMATIONS. ~~Ce terme est facultatif pour le moment par rapport à l'univ de Tours.~~
  * *année* correspond pour le moment à l'année scolaire 2021, on reverra cela après si on peut traiter correctement ou non à partir d'un des futurs champs afin de connaître uniquement la promotion du diplôme (2021 pour un première année, et 2020 pour un deuxième année par exemple)
* des `;` peuvent être utilisés à la place des `,` comme séparateurs de champs, le parser Karuta sait traiter. Comme le fait d'avoir une virgule en fin de ligne cela ne semble pas obligatoire.

### Gestion des différentiels entre deux entrants pour une même univ à des dates différentes

* Pour les ajouts il faut générer un fichier à l'identique de ce qui a été spécifié.
* Pour les suppressions il faut générer un fichier spécifique afin de faire les suppressions manuellement
* Pour les modifications pour le moment il ressortir dans un nouveau fichier les lignes ayant changé, le traitement sera manuel, nous ne savons pas encore spécifier.

### Dépôt des fichiers

Les fichiers seront à déposer sur le serveur epf-karuta1 dans un dossier nommé à la date de génération et sur un chemin paramétrable. Adrien devra avoir accès à cet espace.

### ~~Fichiers distincts par site afin de séparer les sites et les formations~~

~~On garde le nommage actuel sauf qu’après univ-Tours on ajoute univ-tours_site-y~~