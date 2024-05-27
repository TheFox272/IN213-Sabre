# IN213-SABRE

Ce répertoire contient mon projet pour IN213 : le language de programmation *SABRE* (Système À Base de Règles Énumérées).

## Qu'est ce que *SABRE* ?

*SABRE* est un language conçu pour pouvoir facilement énoncer un système de règles, et l'exploiter sans effort pour faire les inférences.  

L'intérpréteur de *SABRE* est donc divisé en 2 modes de fonctionnement :
- **set** : On énonce les règles une par une.
- **use** : On exploite la base de règles. On peut ainsi déclarer des faits et poser des questions, et tous le travail d'inférence est fait en arrière plan.

Pour plus de détail, voir le [manuel](#manuel)


## Contenu du répertoire

Le répertoire est constitué des fichiers suivants :  
- `lexeur.mll` : contient le code du lexeur, qui est responsable de l'analyse lexicale. L'analyse lexicale consiste à découper le texte d'entrée en une suite de tokens, qui sont les unités lexicales du langage.
- `parseur.mly` : contient le code du parseur, qui est responsable de l'analyse syntaxique. Le parseur utilise les tokens générés par le lexeur pour construire un arbre de syntaxe abstraite (AST). Il vérifie que la séquence de tokens respecte la grammaire du langage et produit l'AST en conséquence.
- `ast.ml` : contient la définition de la structure de l'arbre de syntaxe abstraite (AST). L'AST représente la structure hiérarchique du programme source de manière arborescente.
- `sem.ml` : contient l'interpréteur du langage. L'interpréteur parcourt l'AST et exécute les instructions du programme. Il est responsable de l'évaluation des expressions et de l'exécution des commandes en respectant la sémantique du langage. C'est le coeur du système d'inférence.
- `memory.ml` : contient les types et fonctions utilisés pour interagir avec la mémoire. Il gère la représentation des variables, des environnements, et des états mémoire nécessaires à l'exécution des programmes.
- `loop.ml` : contient la boucle principale du programme. La boucle principale initialise les composants, lit les programmes à partir de l'entrée, puis utilise le lexeur, le parseur, l'AST, l'interpréteur et la mémoire pour analyser et exécuter les programmes de manière itérative.
- `exemple.txt` : contient un exemple qui est chargé et utilisé dans [exemple](#exemple-dutilisation-poussé)

**Activer l'affichage du parseur** : Il est possible d'activer l'affichage du parseur dans `loop.ml` en décomentant les 2 * 2 lignes de code surmontées d'un `(* à décommenter pour afficher l'arbre abstrait *)`.

**Avertissement** : Je n'ai malheureusement pas eu le temps de faire le ménage dans `sem.ml`, donc le code est très dense. C'est un fichier assez conséquent, exlusivement récursif, qui sera par conséquent très douloureux à étudier. Je m'en excuse, et j'espère que les commentaires que j'y ai placé vous aideront à rapidement trouver ce que vous chercher si vous vous y aventurez.


## Build & lancement de l'environnement

Pour lancer l'environnement SABRE, il faut d'abord le build. Le script `build.sh` est fait pour ça :
```bash
$ ./build.sh 
ocamllex lexeur.mll
54 states, 529 transitions, table size 2440 bytes
ocamlyacc parseur.mly
2 shift/reduce conflicts.
ocamldep memory.ml sem.ml loop.ml lexeur.ml parseur.ml parseur.mli ast.ml  > .depend
ocamlc  -c ast.ml
ocamlc  -c parseur.mli
ocamlc  -c lexeur.ml
ocamlc  -c parseur.ml
ocamlc  -c memory.ml
ocamlc  -c sem.ml
ocamlc  -c loop.ml
ocamlc  ast.ml lexeur.cmo parseur.cmo parseur.mli memory.cmo sem.cmo loop.cmo -o loop
SABRE build successful!
```

Une fois build, il suffit de lancer le programme `loop` pour entrer dans l'environement SABRE :
```bash
$ ./loop


        Welcome to SABRE, version 0.01

Set your rules with "if <cond1>, <cond2>, ... then <conc1>, <conc2>, ... ."
End the set of rules with ".."
See the current state of the system with "memory"
End the session with "exit"

>
```

Pour quitter l'environnement, il suffit d'écrire le mot clé `exit`, puis de taper sur entrer :
```bash
> exit
See you later !
$
```
**Remarque** : Le message de sortie sera différent selon le mode dans lequel on était.

Enfin, pour nettoyer le répertoire apèrs utilisation, il suffit d'utiliser la commande `make clean` :
```bash
$ make clean
rm -f *.cm[io] *.cmx *~ .*~ *.o
rm -f lexeur.ml parseur.ml parseur.mli
rm -f loop
```


## Manuel

Dans *SABRE*, il n'y a jamais besoin de préciser les types. D'ailleurs, on ne peut pas forcer un type particulier.  

Que ce soit dans [set](#set) ou dans [use](#use), les types des attributs sont en permanence actualisés. Ainsi, un attribut pourra rester sans type et exister. Cela ne posera jamais problème puisqu'au moment de son évaluation il sera typé.  

En parlant d'évaluation, celle-ci n'est faite que dans [use](#use). Dans [set](#set), on ne fait que vérifier la cohérence des types. Cela permet de garder une bonne vision sur ce que l'on a définit lorsque l'on regarde la [mémoire](#mémoire). En effet, l'évaluateur aura tendance à "réduire" les expressions inutilement compliquées, et remplacera les identifiants par leur valeur.  


### Mémoire

Pour jeter un oeil à la mémoire, il suffit d'utiliser le mot clé `memory`. À noter que les **facts** et les **associations** ne seront pas affiché en mode [set](#set), étant de toute façon vide. Voici la structure globale des données :
- **attribute_row** : (id, nom, dans_conditions, dans_conclusions, type, valeurs_possibles, demandable), représente un attribut. On dit qu'il est demandable si aucune règle ne permet de l'obtenir.
- **attribute_table** : tableau mutable d'attributs
- **rules_row** : (id, conditions, conclusions, déclenchée), représente une règle
- **rules_table** : tableau mutable de règles
- **facts-table** : tableau d'assignations (nom := valeur)
- **associations_table** : tableau d'associations (nom := autre_nom)

**Remarque** : en pratique, les types sont un poil plus compliqué que cela. Mais on a ici l'idée principale.


### Set

En mode **set**, l'utilisateur peut seulement ajouter des règles. Les synthaxes à respecter sont les suivantes :
- **rule** : `if <cond1>, <cond2>, ... then <conc1>, <conc2>, ... .` (attention au point à la fin)
- **continuer** : `..` (pour passer en mode [use](#use))
- **condition** : `<identifiant> <comparateur> <expression>`
- **conclusion** : `<identifiant> = <valeur>`
- **identifiant** : `<string>`
- **comparateur** : `=`, `<`, `<=`, `>`, `>=`
- **valeur** : bool, int, -int, symb (pour "symbolique", terme plus adapté pour un attribut que string), identifiant
- **symb** : `"<string>"`
- **expression** : voir dans `parseur.mly`. Il s'agit simplement d'un expression arithmétique.

Rien de spécial à noter sur les types des valeurs, mis à part le fait qu'un string peut contenir des chiffres du moment qu'il ne commence commence bien par une lettre (ou un '_').  

Il faut aussi noter que la négation est un sujet délicat. En effet, peut-on dire que quelque chose est faux si l'on ne peut pas le prouver ? Dans notre cas, on a fait le choix de dire que le `not` se rapportera exclusivement à un booléen : not true = false.  

**Sucre syntaxique** : Dans le cas des conditions et des conclusions, il est aussi possible de mettre simplement `<identifiant>` qui équivaut à `<identifiant> = true`  

Si tout ce passe bien, le message `Rule accepted` devrait vous être répondu. Sinon, c'est que la règle n'a pas été enregistrée. CEla peut être dû à une erreur de syntaxe, ou à un erreur de sémantique.

### Use

En mode **set**, l'utilisateur peut utiliser la base de règles pour faire des inférences :
- **fait** : `<identifiant> = <valeur> !` sert à enoncé un fait permanent, qui entraine potentiellement une série d'inférences calculées immédiatement
- **question fermée** : `<identifiant> <comparateur> <expression> ?` sert à poser une question simple, à laquelle l'interprète répondra par oui ou par non. Il est possible qu'il manque de certaine informations, auquel cas il les demandera à l'utilisateur. Ces informations sont temporaires, et seront oubliées dès la fin de la requête.
- **question ouverte** : `& <identifiant> ?` sert à demander, si c'est possible, la valeur d'un attribut. Là aussi, des informations temporaires peuvent être demandés à l'utilisateur.

**Sucre syntaxique** : Ici aussi, il est aussi possible de mettre simplement `<identifiant>` qui équivaudra à `<identifiant> = true`  

Si tout ce passe bien, le message `Use validated` devrait vous être répondu. Sinon, c'est que le fait n'a pas été enregistré, ou que la question n'était pas valide. Encore une fois, c'est certainement dû à une erreur de syntaxe ou de sémantique.  

Dans ce mode, il est assez intéressant d'observer l'évolution de la [mémoire](#mémoire). En effet, on la voit réellement évoluer, et ce souvent plus que ce qu'on avait anticipé. Je ne détaillerai pas les algorithmes utilisés pour l'inférence, qui me vienne du cours d'INT23 de 1A.  

**Attention** : Je n'ai malheureusement pas réussit à implémenter une version agréable (qui ne redemande pas les mêmes choses trois fois) de l'inférence sur plusieurs niveau i.e. qui va chercher les valeurs des attributs liés à celui auquel on s'interesse. J'ai donc préféré la retirer, et le message `Association found, but not implemented yet` s'affichera lorsque cette inférence est bloquée par l'interprète. Celui ci préferera donc dire qu'il ne peut rien dire plutôt que d'interroger l'utilisateur lorsque qu'une question lui est posée sur un problème où cela entre en jeu.


### Chargement d'un fichier

Afin d'éviter d'avoir à toujours réénoncer les règles et potentiellement les faits que l'on veut utiliser, il est possible de charger un fichier dans l'interpréteur avant de passer en mode utilisateur :
```bash
$ ./loop --help
Usage: ./loop
        Enter the SABRE environment
Usage: ./loop [file]
        Read a SABRE program from file before entering the environment
```

**Remarque** : Faites bien attention à la synthaxe de votre fichier selon le mode dans lequel vous vouler entrer.


### Exemple d'utilisation simple

Commençons par quelque chose de très simple. On va énoncé une seule règle :

```bash
$ ./loop 


        Welcome to SABRE, version 1.0

Set your rules with "if <cond1>, <cond2>, ... then <conc1>, <conc2>, ... ."
End the set of rules with ".."
See the current state of the system with "memory"
End the session with "exit"

> if hello then world.
Rule accepted.
```

Voyons ce que ça donne en mémoire :
```bash
> memory
Attributes:
id | name | cond | conc | type | values | askable
0  | hello | 0 |  | bool |  | askable
1  | world |  | 0 | bool | true | non-askable
Rules:
id | cond -> conc | triggered
0  | (hello = true) -> world := true | non-triggered
```

Tout à l'air en place. Testons ça en utilisant la base :
```bash
> ..

Rules are set.

State a fact with "<fact1>, <fact2>, ... !"
Ask a question with "<question> ?" or "& <name> ?"
See the current state of the system with "memory"
End the session with "exit"

> hello !
Use validated.

> world ?

This affirmation is true
Use validated.
```

Super, ça marche. On peut maintenant quitter cette session et essayer quelque chose de plus compliqué :
```bash
> exit
See you later !
```


### Exemple d'utilisation poussé

On va s'amuser un peu avec la base de règles suivantes (située dans `exemple.txt`) :

```bash
if temperature >= 25 then habits = "tshirt".
if temperature >= 15, temperature < 25 then habits = "veste_legere".
if temperature < 15 then habits = "manteau_chaud".
if meteo = "pluvieux" then accessoire = "parapluie".
if meteo = "neigeux", saison="ete" then accessoire = "bonnet".
if meteo = "neigeux", saison="hiver" then accessoire = "echarpe".
..
```

Commençons par charger ces règles :
```bash
$ ./loop exemple.txt 


        Welcome to SABRE, version 1.0

Set your rules with "if <cond1>, <cond2>, ... then <conc1>, <conc2>, ... ."
End the set of rules with ".."
See the current state of the system with "memory"
End the session with "exit"

> Rule accepted.

> Rule accepted.

> Rule accepted.

> Rule accepted.

> Rule accepted.

> Rule accepted.

> 
Rules are set.

State a fact with "<fact1>, <fact2>, ... !"
Ask a question with "<question> ?" or "& <name> ?"
See the current state of the system with "memory"
End the session with "exit"

> >
```

On voit que l'on a bien interprété les 6 règles sans problème. Testons les un peu et voyons comment la mémoire réagit :

```bash
> > meteo="pluvieux"!
Use validated.

> memory
Attributes:
id | name | cond | conc | type | values | askable
0  | temperature | 0, 1, 1, 2 |  | int |  | askable
1  | habits |  | 0, 1, 2 | symb | "manteau_chaud", "veste_legere", "tshirt" | non-askable
2  | meteo | 3, 4, 5 |  | symb |  | askable
3  | accessoire |  | 3, 4, 5 | symb | "echarpe", "bonnet", "parapluie" | non-askable
4  | saison | 4, 5 |  | symb |  | askable
Rules:
id | cond -> conc | triggered
0  | (temperature >= 25) -> habits := "tshirt" | non-triggered
1  | (temperature >= 15), (temperature < 25) -> habits := "veste_legere" | non-triggered
2  | (temperature < 15) -> habits := "manteau_chaud" | non-triggered
3  |  -> accessoire := "parapluie" | triggered
4  | (meteo = "neigeux"), (saison = "ete") -> accessoire := "bonnet" | non-triggered
5  | (meteo = "neigeux"), (saison = "hiver") -> accessoire := "echarpe" | non-triggered
Facts:
accessoire := "parapluie", meteo := "pluvieux"
Associations:
```

On voit ici que le fait `accessoire := "parapluie"` s'est ajouté automatiquement. On peut d'ailleurs le vérifier en posant le question :
```bash
> & accessoire ?

accessoire = "parapluie"
Use validated.
```

Essayons quelque chose de plus compliqué. Demandons la valeur de `habits`, qui n'est lui pas dans les faits :
```bash
> & habits ?
Is temperature < 15 ? (y/n)
n
Is temperature >= 15 ? (y/n)
y
Is temperature < 25 ? (y/n)
y

habits = "veste_legere"
Use validated.
```

On voit que fasse au manque d'informations, l'interpréteur à pris les devant et nous a demandé des informations supplémentaires. Ces informations ne reste valides que pour la durée de la question, afin de pouvoir en poser plusieurs sans influencer la mémoire. Si l'on se rend compte que l'on a oublié de préciser la température, on peut le faire définitivement avec un fait :
```bash
> temperature = 17!
Use validated.

> memory
Attributes:
id | name | cond | conc | type | values | askable
0  | temperature | 0, 1, 1, 2 |  | int |  | askable
1  | habits |  | 0, 1, 2 | symb | "manteau_chaud", "veste_legere", "tshirt" | non-askable
2  | meteo | 3, 4, 5 |  | symb |  | askable
3  | accessoire |  | 3, 4, 5 | symb | "echarpe", "bonnet", "parapluie" | non-askable
4  | saison | 4, 5 |  | symb |  | askable
Rules:
id | cond -> conc | triggered
0  | (temperature >= 25) -> habits := "tshirt" | non-triggered
1  |  -> habits := "veste_legere" | triggered
2  | (temperature < 15) -> habits := "manteau_chaud" | non-triggered
3  |  -> accessoire := "parapluie" | triggered
4  | (meteo = "neigeux"), (saison = "ete") -> accessoire := "bonnet" | non-triggered
5  | (meteo = "neigeux"), (saison = "hiver") -> accessoire := "echarpe" | non-triggered
Facts:
habits := "veste_legere", temperature := 17, accessoire := "parapluie", meteo := "pluvieux"
Associations:
```

Attention, il n'est maintenant plus possible de modifier ces faits. C'est la contrepartie de faire des inférences immédiates, on ne peut plus les inverser :
```bash
> temperature=18!
Error: add_fact: fact temperature already in the table
Use not validated
```

Pour finir, interrogant la base de plusieurs manières :
```bash
> habits >= 5?
Error: Expected two integers but got a symb and a int
Use not validated

> habits = "jean"?

This affirmation could not be deduced
Use validated.

> habits = "veste_legere"
?

This affirmation is true
Use validated.

> exit
See you later !
```

Bon a va s'arrêter là, j'espère que vous pourrez vous aussi vous amuser avec *SABRE* :)


### Remerciement

Je tenais à vous remercier pour ce projet qui est assez libre mais potentiellement très complet et très intéressant ! Il m'a beaucoup plus, et j'aurais aimé pouvoir avoir plus de temps à y consacrer. Qui sait, j'y reviendrais peut-être un jour ^^
