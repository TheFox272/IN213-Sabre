%{
open Ast ;;
%}

// Definition des tokens
%token TRUE FALSE
%token <int> INT
%token <string> SYMBOLIC
%token <string> IDENT
%token PLUS MINUS MULT DIV EQUAL GREATER SMALLER GREATEREQUAL SMALLEREQUAL
%token NOT
%token COMMA, DOT, DOUBLEDOT
%token IF THEN
%token IMPERATIVE, INTEROGATIVE, VALUE
%token MEMORY, EXIT

// Regles de priorite
%left EQUAL GREATER SMALLER GREATEREQUAL SMALLEREQUAL
%left PLUS MINUS
%left MULT DIV
%left NOT

%start set
%type <Ast.expr> set
%start use
%type <Ast.expr> use


%%

(* Point d'entree de set *)
set: rule_expr DOT { $1 }
    | DOT { raise (Invalid_argument "") }
    | DOUBLEDOT { raise (Move_on) }
    | MEMORY { raise (Memory) }
    | EXIT { raise (Exit)}
;

(* Point d'entree de use *)
use: fact_expr IMPERATIVE { $1 }
    | IMPERATIVE { raise (Invalid_argument "") }
    | ask_expr INTEROGATIVE { $1 }
    | INTEROGATIVE { raise (Invalid_argument "") }
    | MEMORY { raise (Memory) }
    | EXIT { raise (Exit)}
;

/* Grammaire set */

rule_expr:
  IF cond_expr THEN conc_expr  { ERule ($2, $4) }
;

cond_expr:
  atomic_cond_expr COMMA cond_expr   { EList ($1, $3) }
| atomic_cond_expr                   { EList ($1, EBool (true)) }
;

conc_expr:
  atomic_conc_expr COMMA conc_expr     { EList ($1, $3) }
| atomic_conc_expr                     { EList ($1, EInt (1)) }
;

atomic_cond_expr:
  IDENT EQUAL arith_expr             { EBinop ("=", EIdent ($1), $3) } (* Pour une raison inconnue, cette ligne est necessaire pour ne pas confondre avec atomic_conc_expr *)
| arith_expr EQUAL arith_expr        { EBinop ("=", $1, $3) }
| arith_expr GREATER arith_expr      { EBinop (">", $1, $3) }
| arith_expr GREATEREQUAL arith_expr { EBinop (">=", $1, $3) }
| arith_expr SMALLER arith_expr      { EBinop ("<", $1, $3) }
| arith_expr SMALLEREQUAL arith_expr { EBinop ("<=", $1, $3) }
| NOT arith_expr                     { EBinop ("=", $2, EBool (false)) }
| arith_expr                         { EBinop ("=", $1, EBool (true)) }
;

atomic_conc_expr:
  IDENT EQUAL arith_expr        { EAffect ($1, $3) }
| NOT IDENT               { EAffect ($2, EBool (false)) }
| IDENT                   { EAffect ($1, EBool (true)) }
;

arith_expr:
| arith_expr PLUS arith_expr         { EBinop ("+", $1, $3) }
| arith_expr MINUS arith_expr        { EBinop ("-", $1, $3) }
| arith_expr MULT arith_expr         { EBinop ("*", $1, $3) }
| arith_expr DIV arith_expr          { EBinop ("/", $1, $3) }
| application                        { $1 }
;

/* On considere ci-dessous que MINUS atom est dans la categorie
 * des applications. Cela permet de traiter n - 1
 * comme une soustraction binaire, et       f (- 1)
 * comme l'application de f a l'oppose de 1.
 */

application:
  MINUS atom       { EMonop ("-", $2) }
| atom             { $1 }
;

atom:
  TRUE           { EBool (true) }
| FALSE          { EBool (false) }
| INT            { EInt ($1) }
| SYMBOLIC       { ESymb ($1) }
| IDENT          { EIdent ($1) }
;


/* Grammaire use */

fact_expr:
  atomic_conc_expr COMMA fact_expr   { EList ($1, $3) }
| atomic_conc_expr                  { EList ($1, EInt (1)) }
;

ask_expr:
  atomic_cond_expr { EAsk ($1) }
| VALUE IDENT      { EAsk (EIdent ($2)) }
;


