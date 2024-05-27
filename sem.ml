open Ast;;

(* Partie set *)


let printmem oc attributes rules =
  let rec print_index_list l = match l with
    | [] -> ()
    | [x] -> Printf.fprintf oc "%d" x
    | x::q -> Printf.fprintf oc "%d, " x; print_index_list q
  in
  let rec print_values values = match values with
    | [] -> ()
    | [v] -> Ast.print oc v
    | v::q -> Ast.print oc v; Printf.fprintf oc ", "; print_values q
  in
  let rec printmem_aux attributes = match attributes with
    | [] -> ()
    | (id, name, cond, conc, type_, values, askable)::q ->
      (
        Printf.fprintf oc "%d  | %s | " id name;
        print_index_list cond;
        Printf.fprintf oc " | ";
        print_index_list conc;
        Printf.fprintf oc " | %s | " (Memory.string_of_attr_type type_);
        print_values values;
        Printf.fprintf oc " | %s\n" (if askable then "askable" else "non-askable");
        printmem_aux q
      )
  in
  let rec print_list cond = match cond with
    | [] -> ()
    | [expr] -> Ast.print oc expr
    | expr::q ->
      (
        Ast.print oc expr;
        Printf.fprintf oc ", ";
        print_list q
      )
  in
  let rec printrules rules = match rules with
    | [] -> ()
    | (id, cond, conc, triggered)::q ->
      (
        Printf.fprintf oc "%d  | " id;
        print_list cond;
        Printf.fprintf oc " -> ";
        print_list conc;
        Printf.fprintf oc " | %s\n" (if triggered then "triggered" else "non-triggered");
        printrules q
      )
  in
  Printf.fprintf oc "Attributes:\n";
  Printf.fprintf oc "id | name | cond | conc | type | values | askable\n";
  printmem_aux attributes;
  Printf.fprintf oc "Rules:\n";
  Printf.fprintf oc "id | cond -> conc | triggered\n";
  printrules rules
;;


let rec deduce_type e attributes = match e with
  | EBool _ -> Memory.Bool
  | EInt _ -> Memory.Int
  | ESymb _ -> Memory.Symb
  | EIdent s ->
    (
      let att = Memory.get_attribute attributes s in
      match att with
      | None -> Memory.Unknown
      | Some (_, _, _, _, type_, _, _) -> type_
    )
  | EMonop ("-", _) -> Memory.Int
  | EMonop (_, _) -> raise (Failure "Invalid monop")
  | EBinop ("+", e1, e2) | EBinop ("-", e1, e2) | EBinop ("*", e1, e2) | EBinop ("/", e1, e2) -> Memory.Int
  | EBinop ("<", e1, e2) | EBinop (">", e1, e2) | EBinop ("<=", e1, e2) | EBinop (">=", e1, e2) -> Memory.Bool
  | EBinop ("=", e1, e2) -> Memory.Bool
  | _ -> raise (Failure "Could not deduce type")
;;

let handle_attribute s mem_type values attributes id_rule =
  let att = Memory.get_attribute attributes s in
  match att with
  | None ->
    (match id_rule with
    | [id_r] ->
      if values = [] then
        (Memory.add_attribute attributes s mem_type id_r [] true; false)
      else
        (Memory.add_attribute attributes s mem_type id_r values false; false)
    | _ -> raise (Failure "This should not happen"))
  | Some (id, name, cond, conc, type_, values_, askable) ->
      if values = [] then
        (let new_cond = cond @ id_rule in
        let new_askable = if askable then true else false in
        Memory.change_attribute attributes (id, name, new_cond, conc, mem_type, values, new_askable))
      else
        (let new_conc = conc @ id_rule in
        let new_values = values @ values_ in
        Memory.change_attribute attributes (id, name, cond, new_conc, mem_type, new_values, false))
  ;;

let rec rerun_rules attributes rules =
  let rec run_cond_list cond_list =
    match cond_list with
    | [] -> ()
    | e::q -> ignore (compile_atomic_cond e attributes rules []); run_cond_list q
  in
  let rec run_conc_list conc_list =
    match conc_list with
    | [] -> ()
    | e::q -> ignore (compile_atomic_conc e attributes rules []); run_conc_list q
  in
  match rules with
  | [] -> ()
  | (id, cond, conc, triggered)::q ->
    ignore (run_cond_list cond);
    ignore (run_conc_list conc);
    rerun_rules attributes q

and compile_atomic_cond e attributes rules_value rule_id =
  let local_handle_attribute s mem_type =
    let changed_type = handle_attribute s mem_type [] attributes rule_id in
    if changed_type then
      rerun_rules attributes rules_value
  in
  let rec handle_expr e mem_type =
    match e with
    | EBool _ -> if mem_type == Memory.Bool then () 
                  else 
                    let error_msg = Printf.sprintf "Expected a %s but got a boolean (in rule condition)" (Memory.string_of_attr_type mem_type)
                    in raise (Failure error_msg)
    | EInt _ -> if mem_type == Memory.Int then ()
                else
                    let error_msg = Printf.sprintf "Expected a %s but got an integer (in rule condition)" (Memory.string_of_attr_type mem_type)
                    in raise (Failure error_msg)
    | ESymb _ -> if mem_type == Memory.Symb then ()
                  else
                    let error_msg = Printf.sprintf "Expected a %s but got a symbol (in rule condition)" (Memory.string_of_attr_type mem_type)
                    in raise (Failure error_msg)
    | EIdent s -> local_handle_attribute s mem_type
    | EMonop ("-", e) -> if mem_type == Memory.Int then handle_expr e Memory.Int
                          else
                            let error_msg = Printf.sprintf "Expected a %s but got an integer (in rule condition)" (Memory.string_of_attr_type mem_type)
                            in raise (Failure error_msg)
    | EMonop (_, e) -> raise (Failure "Invalid monop (in rule condition)")
    | EBinop ("+", e1, e2) | EBinop ("-", e1, e2) | EBinop ("*", e1, e2) | EBinop ("/", e1, e2) ->
        handle_expr e1 Memory.Int; handle_expr e2 Memory.Int
    | EBinop ("<", e1, e2) | EBinop (">", e1, e2) | EBinop ("<=", e1, e2) | EBinop (">=", e1, e2) ->
        handle_expr e1 Memory.Int; handle_expr e2 Memory.Int
    | EBinop ("=", e1, e2) ->
        let type1 = deduce_type e1 attributes in
        let type2 = deduce_type e2 attributes in
        if type1 = type2 then
          (handle_expr e1 type1; handle_expr e2 type2)
        else if type1 = Memory.Unknown then
          (handle_expr e2 type2; handle_expr e1 type2)
        else if type2 = Memory.Unknown then
          (handle_expr e1 type1; handle_expr e2 type1)
        else
          let error_msg = Printf.sprintf "Comparison between %s and %s (in rule condition)" (Memory.string_of_attr_type type1) (Memory.string_of_attr_type type2)
          in raise (Failure error_msg)
    | EBinop (_, e1, e2) -> raise (Failure "Invalid binop (in rule condition)")
    | _ -> raise (Failure "Could not handle expression (in rule condition)")
  in handle_expr e Memory.Bool;
  e

and compile_atomic_conc e attributes rules_value rule_id =
  let local_handle_attribute s mem_type value =
    let changed_type = handle_attribute s mem_type [value] attributes rule_id in
    if changed_type then
      rerun_rules attributes rules_value
  in
  let rec handle_expr e =
    match e with
    | EAffect(id, EBool b) -> local_handle_attribute id Memory.Bool (EBool b)
    | EAffect(id, EInt i) -> local_handle_attribute id Memory.Int (EInt i)
    | EAffect(id, EMonop ("-", EInt i)) -> local_handle_attribute id Memory.Int (EInt (-i))
    | EAffect(id, ESymb s) -> local_handle_attribute id Memory.Symb (ESymb s)
    | EAffect(id1, EIdent id2) ->
      let type_id1 = deduce_type (EIdent id1) attributes in
      let type_id2 = deduce_type (EIdent id2) attributes in
      if type_id1 = type_id2 then
        (
          local_handle_attribute id1 type_id1 (EIdent id1);
          local_handle_attribute id2 type_id2 (EIdent id2)
        )
      else if type_id1 = Memory.Unknown then
        local_handle_attribute id1 type_id2 (EIdent id2)
      else if type_id2 = Memory.Unknown then
        local_handle_attribute id1 type_id1 (EIdent id2)
      else
        let error_msg = Printf.sprintf "Assignment between %s and %s (in rule conclusion)" (Memory.string_of_attr_type type_id1) (Memory.string_of_attr_type type_id2)
        in raise (Failure error_msg)
    | _ -> raise (Failure "Conclusions should be assignments")
  in
  handle_expr e;
  e
;;


let rec compile_cond e attributes rules rule_id =
  match e with
  | EList (c, EBool (true)) -> [compile_atomic_cond c attributes rules [rule_id]]
  | EList (c1, c2) -> compile_atomic_cond c1 attributes rules [rule_id] :: compile_cond c2 attributes rules rule_id
  | _ -> raise (Failure "Condition compiler expected a condition list")


let rec compile_conc e attributes rules rule_id =
  match e with
  | EList (c, EInt (1)) -> [compile_atomic_conc c attributes rules [rule_id]]
  | EList (c1, c2) -> compile_atomic_conc c1 attributes rules [rule_id] :: compile_conc c2 attributes rules rule_id
  | _ -> raise (Failure "Conclusion compiler expected a conclusion list")
;;

let compile_rule e attributes rules = match e with
  | ERule (condition, conclusion) ->
    let rule_id = List.length !rules in
    let cond_list = compile_cond condition attributes !rules rule_id in
    let conc_list = compile_conc conclusion attributes !rules rule_id in
    rules := !rules @ [(rule_id, cond_list, conc_list, false)]
  | _ -> raise (Failure "Expected a rule")
;;


(******************************************************************************)
(* Partie ask *)


let printfacts oc facts =
  let rec printfacts_aux facts = match facts with
    | [] -> ()
    | [e] -> Ast.print oc e
    | e::q -> Ast.print oc e; Printf.fprintf oc ", "; printfacts_aux q
  in
  Printf.fprintf oc "Facts:\n";
  printfacts_aux facts;
  Printf.fprintf oc "\n"
;;

let printassociations oc associations =
  let rec printassoc_aux assoc = match assoc with
    | [] -> ()
    | [(n, e)] -> Printf.fprintf oc "%s -> " n; Ast.print oc e
    | (n, e)::q -> Printf.fprintf oc "%s -> " n; Ast.print oc e; Printf.fprintf oc ", "; printassoc_aux q
  in
  Printf.fprintf oc "Associations:\n";
  printassoc_aux associations;
  Printf.fprintf oc "\n"
;;

let rec evaluate e attributes rules_value facts_value current_type =
  match e with
  | EBool b -> Some (EBool b), Memory.Bool
  | EInt i -> Some (EInt i), Memory.Int
  | ESymb s -> Some (ESymb s), Memory.Symb
  | EIdent s ->
    let att = Memory.get_attribute attributes s in
    (match att with
    | None -> let error_msg = Printf.sprintf "Unknown identifier %s" s in raise (Failure error_msg)
    | Some (id, name, cond, conc, type_, values, askable) ->
      if type_ = Memory.Unknown && current_type != Memory.Unknown then
        (ignore (Memory.change_attribute attributes (id, name, cond, conc, current_type, values, askable));
        rerun_rules attributes rules_value;
        None, current_type)
      else if type_ = Memory.Unknown then None, Memory.Unknown
      else let value = Memory.get_value facts_value name in value, type_)
  | EMonop ("-", e) ->
    let value, mem_type = evaluate e attributes rules_value facts_value Memory.Int in
    (match mem_type with
    | Memory.Int ->
      (match value with
      | Some (EInt i) -> Some (EInt (-i)), Memory.Int
      | None -> None, Memory.Int
      | _ -> raise (Failure "False integer encountered in monop evaluation"))
    | Memory.Unknown -> None, Memory.Unknown
    | _ -> let error_msg = Printf.sprintf "Expected an integer but got a %s" (Memory.string_of_attr_type mem_type) in raise (Failure error_msg))
  | EMonop (_, _) -> raise (Failure "Invalid monop")
  | EBinop ("+", e1, e2) | EBinop ("-", e1, e2) | EBinop ("*", e1, e2) | EBinop ("/", e1, e2) ->
    let value1, mem_type1 = evaluate e1 attributes rules_value facts_value Memory.Int in
    let value2, mem_type2 = evaluate e2 attributes rules_value facts_value Memory.Int in
    (match mem_type1, mem_type2 with
    | Memory.Int, Memory.Int ->
      (match value1, value2 with
      | Some (EInt i1), Some (EInt i2) -> (match e with
                                          | EBinop ("+", _, _) -> Some (EInt (i1 + i2)), Memory.Int
                                          | EBinop ("-", _, _) -> Some (EInt (i1 - i2)), Memory.Int
                                          | EBinop ("*", _, _) -> Some (EInt (i1 * i2)), Memory.Int
                                          | EBinop ("/", _, _) -> Some (EInt (i1 / i2)), Memory.Int
                                          | _ -> raise (Failure "Invalid binop"))
      | None, _ | _, None -> None, Memory.Int
      | _ -> raise (Failure "False integer encountered in operation binop evaluation"))
    | Memory.Unknown, _ | _, Memory.Unknown-> None, Memory.Int
    | _, _ -> let error_msg = Printf.sprintf "Expected two integers but got a %s and a %s" (Memory.string_of_attr_type mem_type1) (Memory.string_of_attr_type mem_type2) in raise (Failure error_msg))
  | EBinop ("<", e1, e2) | EBinop (">", e1, e2) | EBinop ("<=", e1, e2) | EBinop (">=", e1, e2) ->
    let value1, mem_type1 = evaluate e1 attributes rules_value facts_value Memory.Int in
    let value2, mem_type2 = evaluate e2 attributes rules_value facts_value Memory.Int in
    (match mem_type1, mem_type2 with
    | Memory.Int, Memory.Int ->
      (match value1, value2 with
      | Some (EInt i1), Some (EInt i2) -> (match e with
                            | EBinop ("<", _, _) -> Some (EBool (i1 < i2)), Memory.Bool
                            | EBinop (">", _, _) -> Some (EBool (i1 > i2)), Memory.Bool
                            | EBinop ("<=", _, _) -> Some (EBool (i1 <= i2)), Memory.Bool
                            | EBinop (">=", _, _) -> Some (EBool (i1 >= i2)), Memory.Bool
                            | _ -> raise (Failure "Invalid binop"))
      | None, _ | _, None -> None, Memory.Bool
      | _ -> raise (Failure "False integer encountered in comparison binop evaluation"))
    | Memory.Unknown, _ | _, Memory.Unknown -> None, Memory.Bool
    | _, _ -> let error_msg = Printf.sprintf "Expected two integers but got a %s and a %s" (Memory.string_of_attr_type mem_type1) (Memory.string_of_attr_type mem_type2) in raise (Failure error_msg))
  | EBinop ("=", e1, e2) ->
    let equal_value value1 value2 =
      match value1, value2 with
      | Some (EInt i1), Some (EInt i2) -> Some (EBool (i1 = i2)), Memory.Bool
      | Some (EBool b1), Some (EBool b2) -> Some (EBool (b1 = b2)), Memory.Bool
      | Some (ESymb s1), Some (ESymb s2) -> Some (EBool (s1 = s2)), Memory.Bool
      | _ -> None, Memory.Bool
    in
    let value1, mem_type1 = evaluate e1 attributes rules_value facts_value Memory.Unknown in
    let value2, mem_type2 = evaluate e2 attributes rules_value facts_value Memory.Unknown in
    (match mem_type1, mem_type2 with
    | Memory.Unknown, Memory.Unknown -> None, Memory.Bool
    | Memory.Unknown, other -> let new_value1, new_mem_type1 = evaluate e1 attributes rules_value facts_value other in equal_value new_value1 value2
    | other, Memory.Unknown -> let new_value2, new_mem_type2 = evaluate e2 attributes rules_value facts_value other in equal_value value1 new_value2
    | Memory.Int, Memory.Int | Memory.Bool, Memory.Bool | Memory.Symb, Memory.Symb -> equal_value value1 value2
    | _, _ -> let error_msg = Printf.sprintf "Equality expected two values of the same type but got a %s and a %s" (Memory.string_of_attr_type mem_type1) (Memory.string_of_attr_type mem_type2) in raise (Failure error_msg))
  | _ -> raise (Failure "Could not evaluate expression")
;;

let rec propagate name value mem_type attributes rules facts associations no_msg =
  let delta_facts = ref [] in
  let rec explore_rules rules_list facts_list =
    match rules_list with
    | [] -> ()
    | (id, cond, conc, false)::q ->
      (let eval_cond c =
        let c_value, c_type = evaluate c attributes !rules facts_list Memory.Bool in
        match c_value with
        | Some (EBool true) -> []
        | Some (EBool false) | None-> [c]
        | _ -> raise (Failure "A condition did not evaluate to a boolean (somehow)")
      in
      let rec reduce_cond current_cond =
        match current_cond with
        | [] -> []
        | c::q -> eval_cond c @ reduce_cond q
      in
      let new_cond = reduce_cond cond in
      if new_cond = [] then
        (Memory.change_rule rules (id, new_cond, conc, true);
        delta_facts := conc @ !delta_facts;
        explore_rules q facts_list)
      else
        Memory.change_rule rules (id, new_cond, conc, false);
        explore_rules q facts_list)
    | (id, cond, conc, true)::q -> explore_rules q facts_list
  in
  let (id, _, cd, cc, type_, values, askable) = match Memory.get_attribute attributes name with
    | None -> let error_msg = Printf.sprintf "Unknown identifier %s" name in raise (Failure error_msg)
    | Some x -> x
  in
  if type_ = Memory.Unknown then
    (ignore (Memory.change_attribute attributes (id, name, cd, cc, mem_type, values, askable));
    rerun_rules attributes !rules);
  Memory.add_fact facts name value no_msg;
  run_associations name value mem_type attributes rules facts associations no_msg;
  let concerned_rules = Memory.get_rules rules cd in
  explore_rules concerned_rules !facts;
  let rec propagate_aux delta =
    match delta with
    | [] -> ()
    | f::q -> (compile_fact f attributes rules facts associations no_msg; propagate_aux q)
  in
  propagate_aux !delta_facts

and compile_fact fact attributes rules facts associations no_msg =
  match fact with
  | EAffect (name, EIdent n) ->
    let value, mem_type = evaluate (EIdent n) attributes !rules !facts Memory.Unknown in
    (match value with
    | None -> associations := (name, EIdent n) :: (n, EIdent name) :: !associations
    | Some v -> propagate name v mem_type attributes rules facts associations no_msg)
  | EAffect (name, expr) ->
    let value, mem_type = evaluate expr attributes !rules !facts Memory.Unknown in
    (match value with
    | None -> Printf.printf "Could not evaluate fact "; Ast.print stdout expr; Printf.printf "\n"; raise (Failure "Bad fact")
    | Some v -> propagate name v mem_type attributes rules facts associations no_msg)
  | _ -> raise (Failure "Expected a fact")

and run_associations name value mem_type attributes rules facts associations no_msg =
  let rec run_associations_aux associations_list assoc_begin =
    match associations_list with
    | [] -> ()
    | (n1, EIdent n2)::q->
      if n1 = name then
        (associations := assoc_begin @ q; propagate n2 value mem_type attributes rules facts associations no_msg)
      else
        run_associations_aux q ((n1, EIdent n2) :: assoc_begin)
    | _ -> raise (Failure "Bad association encountered")
  in run_associations_aux !associations []
;;

let ask_for name op e attributes rules facts associations =
  match (Memory.get_attribute attributes name) with
  | None -> raise (Failure "Unknown identifier")
  | Some (_, _, _, _, _, _, false) -> false
  | Some (_, _, _, _, _, _, true) ->
    (Printf.printf "Is %s %s " name op; Ast.print stdout e; Printf.printf " ? (y/n)\n";
    let rec ask_loop () =
      let answer = read_line () in
      match answer with
      | "y" -> true
      | "n" -> false
      | _ -> (Printf.printf "Please answer by 'y' or 'n'\n"; ask_loop ())
    in
    ask_loop ())
;;

let rec compile_binop_ask a attributes rules facts associations tried =
  match a with
  | EBinop (op, EIdent(name), e) ->
    (let attribute = Memory.get_attribute attributes name in
    match attribute with
      | None -> raise (Failure "Unknown identifier")
      | Some (_, _, _, _, mem_type, values, askable) ->
        begin
          if askable then
            (
              let v, m = evaluate e attributes !rules !facts Memory.Unknown in
              match m with
              | Memory.Unknown -> raise (Failure "Could not evaluate expression")
              | mem_type_e -> if mem_type_e = mem_type then ask_for name op e attributes rules facts associations
                              else let error_msg = Printf.sprintf "Expected a %s but got a %s" (Memory.string_of_attr_type mem_type) (Memory.string_of_attr_type mem_type_e) in raise (Failure error_msg)
            )
          else
      let run = 
      (let value, mem_type = evaluate a attributes !rules !facts Memory.Bool in
    (match value with
     | Some (EBool b) -> b
     | None ->
       (let rec explore_rules rules_list rules_begin =
         match rules_list with
         | [] -> ask_for name op e attributes rules facts associations
         | (id, cond, conc, false) :: q ->
           (let temp_attributes = ref !attributes in
           let temp_rules = ref !rules in
           let temp_facts = ref !facts in
           let temp_associations = ref !associations in
           (* Compile all facts in conc *)
           let rec compile_conc_list conc_list =
             match conc_list with
             | [] -> ()
             | c::qc -> (compile_fact c temp_attributes temp_rules temp_facts temp_associations true; compile_conc_list qc)
           in compile_conc_list conc;
           let temp_value, temp_mem_type = evaluate a temp_attributes !temp_rules !temp_facts Memory.Bool in
           let try_cond c =
              let rec try_all cd =
                match cd with
                | [] -> true
                | c :: qc ->
                  (if List.mem c !tried then try_all qc
                  else (
                    tried := c :: !tried;
                    match compile_binop_ask c attributes rules facts associations tried with
                    | true -> try_all qc
                    | false -> false
                  ))
              in
              match try_all c with
                | true -> true
                | false -> explore_rules q ((id, c, conc, false)::rules_begin)
            in
            match temp_value with
            | Some (EBool false) -> explore_rules q ((id, cond, conc, false)::rules_begin)
            | Some (EBool true) -> try_cond cond
            | None ->
                (let rec explore_associations assos_list assos_begin =
                match assos_list with
                | [] -> false
                | (n1, EIdent n2)::qa ->
                  if n1 = name then
                    (
                      (* let new_rules = ref (q @ rules_begin) in
                      let temp_temp_attributes = ref !temp_attributes in
                      let temp_temp_facts = ref !temp_facts in
                      let temp_temp_associations = ref !temp_associations in
                      if compile_binop_ask (EBinop (op, EIdent n2, e)) temp_temp_attributes new_rules temp_temp_facts temp_temp_associations tried
                      then
                        (temp_attributes := !temp_temp_attributes;
                        temp_rules := !new_rules;
                        temp_facts := !temp_temp_facts;
                        temp_associations := !temp_temp_associations;
                        true) *)
                        Printf.printf "Association found, but not implemented yet\n";
                        false
                      (* else explore_associations qa ((n1, EIdent n2) :: assos_begin) *)
                    )
                  else explore_associations qa ((n1, EIdent n2) :: assos_begin)
                | _ -> raise (Failure "Bad association encountered")
                in
                match explore_associations !temp_associations [] with
                | true -> try_cond cond
                | false -> explore_rules q ((id, cond, conc, false)::rules_begin))
            | _ -> raise (Failure "A condition did not evaluate to a boolean"))
         | (id, cond, conc, true) :: q -> explore_rules q ((id, cond, conc, true)::rules_begin)
       in
       explore_rules !rules [])
       | _ -> let error_msg = Printf.sprintf "Expected a boolean but got a %s" (Memory.string_of_attr_type mem_type) in raise (Failure error_msg)
       ))
      in
    let e_value, _ = evaluate e attributes !rules !facts Memory.Unknown in
    match e_value with
    | Some thing ->
        (
          let rec explore_values v =
            match v with
            | [] -> false
            | ev::qv -> (if evaluate (EBinop (op, ev, thing)) attributes !rules !facts Memory.Bool = (Some (EBool true), Memory.Bool)
                      then run
                      else explore_values qv)
          in explore_values values
        )
    | None -> run
        end)
  | _ -> raise (Failure "Unexpected expression type in binom question")
;;

let rec compile_ask a attributes rules facts associations =
  match a with
  | EIdent name ->
    let attribute = Memory.get_attribute attributes name in
    (match attribute with
    | None -> raise (Failure "Unknown identifier")
    | Some (_, _, _, _, _, values, _) ->
      (
        let rec explore_values v =
          match v with
          | [] -> None
          | e::q ->
            let tried = ref [] in
            let temp_attributes = ref !attributes in
            let temp_rules = ref !rules in
            let temp_facts = ref !facts in
            let temp_associations = ref !associations in
            let b = compile_binop_ask (EBinop ("=", a, e)) temp_attributes temp_rules temp_facts temp_associations tried in
            if b then Some e
            else explore_values q
        in explore_values values
      )
    )
  | _ -> raise (Failure "Unexpected question type")
;;

let rec compile_use e attributes rules facts associations =
  match e with
  | EList(fact, EInt (1)) -> compile_fact fact attributes rules facts associations false
  | EList(fact, fact_q) -> (compile_fact fact attributes rules facts associations false; compile_use fact_q attributes rules facts associations)
  | EAsk(EBinop (op, EIdent(name), e)) ->
    let tried = ref [] in
    let temp_attributes = ref !attributes in
    let temp_rules = ref !rules in
    let temp_facts = ref !facts in
    let temp_associations = ref !associations in
    let b = compile_binop_ask (EBinop (op, EIdent(name), e)) temp_attributes temp_rules temp_facts temp_associations tried in
    if b then Printf.printf "\nThis affirmation is true\n"
    else Printf.printf "\nThis affirmation could not be deduced\n"
  | EAsk(e) ->
    let value = compile_ask e attributes rules facts associations
    in
    (match value with
    | None -> Printf.printf "\n"; Ast.print stdout e; Printf.printf " value could not be deduced\n"
    | Some v -> Printf.printf "\n"; Ast.print stdout e; Printf.printf " = "; Ast.print stdout v; Printf.printf "\n")
  | _ -> raise (Failure "Expected a say or ask")
;;

