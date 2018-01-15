(** This module defines the interpretation of MetaCoq constr
*)

open Ltac_plugin
open Declarations

open List
open String

open Pp
open Environ
open CClosure
open Evd
open Evarutil
open EConstr
open Termops
open Reductionops
open Names
open Util
open Evarconv
open Libnames

open Constrs

[@@@ocaml.warning "-27-40-41-42-44"]

module Stack = Reductionops.Stack

let reduce_value = Tacred.compute

let get_ts env = Conv_oracle.get_transp_state (Environ.oracle env)

(** returns the i-th position of constructor c (starting from 0) *)
let get_constructor_pos sigma c = let (_, pos), _ = destConstruct sigma c in pos-1

module MetaCoqNames = struct
  let metaCoq_module_name = "Mtac2.Base"
  let mkConstr e = Constr.mkConstr (metaCoq_module_name ^ "." ^ e)
  let mkUConstr e = Constr.mkUConstr (metaCoq_module_name ^ "." ^ e)
  let mkBuilder e = ConstrBuilder.from_string (metaCoq_module_name ^ "." ^ e)
  let mkUBuilder e = UConstrBuilder.from_string (metaCoq_module_name ^ "." ^ e)
  let mkT_lazy = mkUConstr "M.t"
  let mkUConstr e = Constr.mkUConstr (metaCoq_module_name ^ "." ^ e)

  let isConstr sigma e =
    let c = Lazy.force (mkConstr e) in
    eq_constr sigma c

  let isUConstr sigma env e =
    let sigma, c = mkUConstr e sigma env in
    eq_constr_nounivs sigma c

  let mkCase ind v ret branch sigma env =
    let sigma, c = mkUConstr "mkCase" sigma env in
    sigma, mkApp(c, [|ind;v;ret;branch|])

  let mkelem d sigma env =
    let sigma, c = mkUConstr "elem" sigma env in
    sigma, mkApp(c, [|d|])

  let mkdyn = mkUConstr "dyn"

  let mkDyn ty el sigma env =
    let sigma, c = mkUConstr "Dyn" sigma env in
    sigma, mkApp(c, [|ty;el|])

  (* dyn is expected to be Dyn ty el *)
  let get_elem sigma dyn = (snd (destApp sigma dyn)).(1)
end

open MetaCoqNames

module TConstr = struct
  let mkconstr s = lazy (let (_, c) = mkUConstr ("M." ^ s) Evd.empty (Global.env ()) in c)
  let isconstr c h = eq_constr_nounivs Evd.empty (Lazy.force c) h

  let mkret = mkconstr "ret"
  let isret  = isconstr mkret

  let mkbind = mkconstr "bind"
  let isbind  = isconstr mkbind

  let mktry' = mkconstr "mtry'"
  let istry'  = isconstr mktry'

  let mkraise = mkconstr "raise'"
  let israise  = isconstr mkraise

  let mkfix1 = mkconstr "fix1"
  let isfix1  = isconstr mkfix1

  let mkfix2 = mkconstr "fix2"
  let isfix2  = isconstr mkfix2

  let mkfix3 = mkconstr "fix3"
  let isfix3  = isconstr mkfix3

  let mkfix4 = mkconstr "fix4"
  let isfix4  = isconstr mkfix4

  let mkfix5 = mkconstr "fix5"
  let isfix5  = isconstr mkfix5

  let mkis_var = mkconstr "is_var"
  let isis_var  = isconstr mkis_var

  let mknu = mkconstr "nu"
  let isnu  = isconstr mknu

  let mkabs_fun = mkconstr "abs_fun"
  let isabs_fun  = isconstr mkabs_fun

  let mkabs_let = mkconstr "abs_let"
  let isabs_let  = isconstr mkabs_let

  let mkabs_prod = mkconstr "abs_prod"
  let isabs_prod  = isconstr mkabs_prod

  let mkabs_fix = mkconstr "abs_fix"
  let isabs_fix  = isconstr mkabs_fix

  let mkget_binder_name = mkconstr "get_binder_name"
  let isget_binder_name  = isconstr mkget_binder_name

  let mkremove = mkconstr "remove"
  let isremove  = isconstr mkremove

  let mkgen_evar = mkconstr "gen_evar"
  let isgen_evar  = isconstr mkgen_evar

  let mkis_evar = mkconstr "is_evar"
  let isis_evar  = isconstr mkis_evar

  let mkhash = mkconstr "hash"
  let ishash  = isconstr mkhash

  let mksolve_typeclasses = mkconstr "solve_typeclasses"
  let issolve_typeclasses  = isconstr mksolve_typeclasses

  let mkprint = mkconstr "print"
  let isprint  = isconstr mkprint

  let mkpretty_print = mkconstr "pretty_print"
  let ispretty_print  = isconstr mkpretty_print

  let mkhyps = mkconstr "hyps"
  let ishyps  = isconstr mkhyps

  let mkdestcase = mkconstr "destcase"
  let isdestcase  = isconstr mkdestcase

  let mkconstrs = mkconstr "constrs"
  let isconstrs  = isconstr mkconstrs

  let mkmakecase = mkconstr "makecase"
  let ismakecase  = isconstr mkmakecase

  let mkunify = mkconstr "unify"
  let isunify  = isconstr mkunify

  let mkunify_univ = mkconstr "unify_univ"
  let isunify_univ  = isconstr mkunify_univ

  let mkget_reference = mkconstr "get_reference"
  let isget_reference  = isconstr mkget_reference

  let mkget_var = mkconstr "get_var"
  let isget_var  = isconstr mkget_var

  let mkcall_ltac = mkconstr "call_ltac"
  let iscall_ltac  = isconstr mkcall_ltac

  let mklist_ltac = mkconstr "list_ltac"
  let islist_ltac  = isconstr mklist_ltac

  let mkread_line = mkconstr "read_line"
  let isread_line  = isconstr mkread_line

  let mkbreak = mkconstr "break"
  let isbreak  = isconstr mkbreak

  let mkdecompose = mkconstr "decompose"
  let isdecompose  = isconstr mkdecompose

  let mksolve_typeclass = mkconstr "solve_typeclass"
  let issolve_typeclass  = isconstr mksolve_typeclass

  let mkdeclare = mkconstr "declare"
  let isdeclare  = isconstr mkdeclare

  let mkdeclare_implicits = mkconstr "declare_implicits"
  let isdeclare_implicits  = isconstr mkdeclare_implicits

  let mkos_cmd = mkconstr "os_cmd"
  let isos_cmd  = isconstr mkos_cmd

  let mkget_debug = mkconstr "get_debug"
  let isget_debug  = isconstr mkget_debug

  let mkset_debug = mkconstr "set_debug"
  let isset_debug  = isconstr mkset_debug

end

module RedList = GenericList (struct
    let nilname = metaCoq_module_name ^ ".rlnil"
    let consname = metaCoq_module_name ^ ".rlcons"
    let typename = metaCoq_module_name ^ ".rllist"
  end)


module Goal = struct

  let mkgoal = mkUConstr "goal"
  let mkGoal = mkUConstr "Goal"
  let mkAHyp = mkUConstr "AHyp"

  let mkTheGoal ty ev sigma env =
    let sigma, tg = mkGoal sigma env in
    sigma, mkApp (tg, [|ty;ev|])

  let mkAHypOrDef (name, odef, ty) body sigma env =
    (* we are going to wrap the body in a function, so we need to lift
       the indices. we also replace the name with index 1 *)
    let body = replace_term sigma (mkVar name) (mkRel 1) (Vars.lift 1 body) in
    let sigma, odef_coq = CoqOption.to_coq sigma env ty odef in
    let sigma, ahyp = mkAHyp sigma env in
    sigma, mkApp (ahyp, [|ty; odef_coq; mkLambda(Name name,ty,body)|])

  (* it assumes goal is of type goal *)
  let evar_of_goal sigma env =
    let rec eog goal =
      let (c, args) = decompose_appvect sigma goal in
      if isConstruct sigma c then
        match get_constructor_pos sigma c with
        | 0 -> (* AGoal *)
            let evar = whd_evar sigma args.(1) in
            if isEvar sigma evar then
              Some (fst (destEvar sigma evar))
            else (* it is defined *)
              None
        | 1 -> (* AHyp *)
            let func = args.(2) in
            if isLambda sigma func then
              let (_, _, body) = destLambda sigma func in
              eog body
            else
              None
        | 2 -> (* RemHyp *)
            eog args.(2)
        | _ -> failwith "Should not happen"
      else
        CErrors.user_err Pp.(str "Not a goal")
    in eog

  let goal_of_evar (env:env) sigma ev =
    let open Context.Named in
    let evinfo = Evd.find_undefined sigma ev in
    let evenv = named_context_of_val (evar_hyps evinfo) in
    (* we remove the elements in the hypotheses that are shared with
       the current env (old to new). *)
    let newenv =
      let rec remove = function
        | (nd1 :: evenv) as l1, (nd2 :: env) ->
            if Declaration.equal (eq_constr sigma) nd1 nd2 then
              remove (evenv, env)
            else
              l1
        | l1, _ -> l1 in
      List.rev (remove (List.rev evenv, List.rev (named_context env))) in
    let ids = List.map (fun v -> Term.mkVar (Declaration.get_id v)) evenv in
    let evar = (ev, Array.of_list ids) in
    let sigma, tg = mkTheGoal (of_constr @@ Evd.existential_type sigma evar) (of_constr @@ Term.mkEvar evar) sigma env in
    fold_inside (fun (sigma,s) v -> mkAHypOrDef (Declaration.to_tuple v) s sigma env) newenv ~init:(sigma,tg)

end

let constr_to_string_env env sigma t = string_of_ppcmds (Termops.print_constr_env sigma env t)

module Exceptions = struct

  let mkCannotRemoveVar env sigma x =
    let varname = CoqString.to_coq (constr_to_string_env env sigma x) in
    let sigma, exc = (mkUConstr "CannotRemoveVar" env sigma) in
    sigma, mkApp(exc, [|varname|])

  let mkRefNotFound sigma env s =
    let msg = CoqString.to_coq s in
    let sigma, exc = (mkUConstr "RefNotFound" sigma env) in
    sigma, mkApp (exc, [|msg|])

  let mkTermNotGround sigma env () = (mkUConstr "TermNotGround" sigma env)
  let mkWrongTerm sigma env () = (mkUConstr "WrongTerm" sigma env)
  let mkHypMissesDependency sigma env () = (mkUConstr "HypMissesDependency" sigma env)
  let mkTypeMissesDependency sigma env () = (mkUConstr "TypeMissesDependency" sigma env)
  let mkAbsDependencyError sigma env () = (mkUConstr "AbsDependencyError" sigma env)
  let mkExceptionNotGround sigma env () = (mkUConstr "ExceptionNotGround" sigma env)
  let mkDuplicatedVariable sigma env () = (mkUConstr "DuplicatedVariable" sigma env)
  let mkNotAVar sigma env () = (mkUConstr "NotAVar" sigma env)
  let mkStuckTerm sigma env () = (mkUConstr "StuckTerm" sigma env)
  let mkNotAList sigma env () = (mkUConstr "NotAList" sigma env)
  let mkNotAMatchExp sigma env () = (mkUConstr "NotAMatchExp" sigma env)
  let mkVarAppearsInValue sigma env () = (mkUConstr "VarAppearsInValue" sigma env)
  let mkNotAReference sigma env ty t =
    let sigma, exc = (mkUConstr "NotAReference" sigma env) in
    sigma, mkApp (exc, [|ty; t|])
  let mkAlreadyDeclared sigma env name =
    let sigma, exc = (mkUConstr "AlreadyDeclared" sigma env) in
    sigma, mkApp (exc, [|name|])
  let mkTypeErrorUnboundVar sigma env () = (mkUConstr "UnboundVar" sigma env)

  let mkLtacError sigma env msg =
    let sigma, e = mkUConstr "LtacError" sigma env in
    let coqmsg = CoqString.to_coq msg in
    sigma, mkApp(e, [|coqmsg|])

  let mkNameExists sigma env s =
    let sigma, exc = (mkUConstr "NameExistsInContext" sigma env) in
    sigma, mkApp (exc, [|s|])

  let block msg = CErrors.user_err Pp.(str msg)
end

module E = Exceptions

module ReductionStrategy = struct
  open MetaCoqNames
  open Reductionops
  open CClosure
  open CClosure.RedFlags
  open Context

  let isReduce sigma env c = isUConstr sigma env "reduce" c

  let has_definition ts env sigma t =
    if isVar sigma t then
      let var = destVar sigma t in
      if not (is_transparent_variable ts var) then
        false
      else
        let n = Environ.lookup_named var env in
        Option.has_some (Named.Declaration.get_value n)
    else if isRel sigma t then
      let n = destRel sigma t in
      let n = Environ.lookup_rel n env in
      Option.has_some (Rel.Declaration.get_value n)
    else if isConst sigma t then
      let (c, _) = destConst sigma t in
      is_transparent_constant ts c && Environ.evaluable_constant c env
    else
      false

  let get_definition env sigma t : EConstr.t =
    if isVar sigma t then
      let var = destVar sigma t in
      let n = EConstr.lookup_named var env in
      match Named.Declaration.get_value n with
      | Some c -> c
      | _ -> CErrors.anomaly (Pp.str "get_definition for var didn't have definition!")
    else if isRel sigma t then
      let n = destRel sigma t in
      let d = Environ.lookup_rel n env in
      match Rel.Declaration.get_value d with
      | Some v -> (Vars.lift n) (of_constr v)
      | _ -> CErrors.anomaly (Pp.str "get_definition for rel didn't have definition!")
    else if isConst sigma t then
      let (c,ui) = destConst sigma t in
      let ui = EInstance.kind sigma ui in
      let (d,_) = Environ.constant_value env (c,ui) in
      of_constr d
    else
      CErrors.anomaly (Pp.str "get_definition didn't have definition!")

  let try_unfolding ts env sigma t =
    if has_definition ts env sigma t then
      get_definition env sigma t
    else
      t

  let one_step env sigma c =
    let ts = get_ts env in
    let h, args = decompose_app sigma c in
    let h = whd_evar sigma h in
    let r =
      match kind sigma h with
      | Lambda (_, _, trm) when args <> [] ->
          (Vars.subst1 (List.hd args) trm, List.tl args)
      | LetIn (_, trm, _, body) -> (Vars.subst1 trm body, args)
      | Var _ | Rel _ | Const _ -> (try_unfolding ts env sigma h, args)
      | _ -> h, args
    in applist r

  let redflags = [|fBETA;fDELTA;fMATCH;fFIX;fZETA|]
  let posDeltaC = Array.length redflags
  let posDeltaX = posDeltaC + 1
  let posDeltaOnly = posDeltaX + 1
  let posDeltaBut = posDeltaOnly + 1

  let get_flags (env, sigma as ctx) flags =
    (* we assume flags have the right type and are in nf *)
    let flags = RedList.from_coq sigma env flags in
    List.fold_right (fun f reds->
      if isConstruct sigma f then
        let ci = get_constructor_pos sigma f in
        if ci < Array.length redflags then
          red_add reds redflags.(ci)
        else if ci = posDeltaC then
          red_add_transparent reds Names.cst_full_transparent_state
        else if ci = posDeltaX then
          red_add_transparent reds Names.var_full_transparent_state
        else
          failwith "Unknown flag"
      else if isApp sigma f then
        let c, args = destApp sigma f in
        if isConstruct sigma c && Array.length args = 1 then
          let reds, func =
            if get_constructor_pos sigma c = posDeltaOnly then
              red_add_transparent (red_add reds fDELTA) all_opaque,
              red_add
            else (* must be posDeltaBut *)
              red_add_transparent reds
                (Conv_oracle.get_transp_state (Environ.oracle env)),
              red_sub in
          let (sigma, ids) = RedList.from_coq_conv sigma env (fun sigma x -> sigma, get_elem sigma x) args.(0) in
          List.fold_right (fun e reds->
            if isVar sigma e then
              func reds (fVAR (destVar sigma e))
            else if isConst sigma e then
              func reds (fCONST (fst (destConst sigma e)))
            else
              failwith "Unknown reference") ids reds
        else
          failwith "Unknown flag"
      else
        failwith "Unknown flag"
    ) flags no_red

  let redfuns = [|
    (fun _ _ _ c -> c);
    (fun _ env sigma c -> Tacred.simpl env sigma (nf_evar sigma c));
    (fun _ ->one_step);
    (fun fs env sigma c ->
       (* Environ.env -> Evd.evar_map -> EConstr.constr -> EConstr.constr *)
       Reductionops.clos_whd_flags (get_flags (env, sigma) fs.(0)) env sigma c);
    (* let evars ev = safe_evar_value sigma ev in *)
    (* of_constr @@
     * whd_val
     *   (create_clos_infos ~evars (get_flags (env, sigma) fs.(0)) env)
     *   (inject (EConstr.to_constr sigma c))); *)
    (fun fs env sigma->
       clos_norm_flags (get_flags (env, sigma) fs.(0)) env sigma);
    (fun _ -> Redexpr.cbv_vm) (* vm_compute *)
  |]

  let reduce sigma env strategy c =
    let strategy, args = decompose_appvect sigma strategy in
    redfuns.(get_constructor_pos sigma strategy) args env sigma c

  (* XXX: Port to 8.7: [EJGA]

     These functions take and return `Constr.t` instead of the
     preferred `Econstr.t`. This implies a large performance cost in
     some cases as the called has to perform evar substitution using
     `EConstr.to_constr`

     The most plausible fix is to use instead
     `Reductionops.clos_whd_flags`, however @SkySkimmer notes that
     it catches anomalies so a minor difference may exist.
  *)
  let whdfun flags env sigma c =
    let evars = safe_evar_value sigma in
    whd_val
      (create_clos_infos ~evars flags env)
      (inject c)

  (* let whd_betadeltaiota_nolet = whdfun CClosure.allnolet *)
  let whd_betadeltaiota_nolet = Reductionops.clos_whd_flags CClosure.allnolet

  (* let whd_betadeltaiota = whdfun CClosure.all *)
  let whd_betadeltaiota = Reductionops.clos_whd_flags CClosure.all

  (* let whd_betadelta = whdfun (red_add beta fDELTA) *)
  let whd_betadelta = Reductionops.clos_whd_flags (red_add beta fDELTA)

  (* let whd_betaiotazeta = whdfun betaiotazeta *)
  let whd_betaiotazeta = Reductionops.clos_whd_flags betaiotazeta

  (* let whd_betaiota = whdfun betaiota *)
  let whd_betaiota = Reductionops.clos_whd_flags betaiota

end

module RE = ReductionStrategy

module UnificationStrategy = struct
  open Evarsolve

  let find_pbs sigma evars =
    let (_, pbs) = extract_all_conv_pbs sigma in
    List.filter (fun (_,_,c1,c2) ->
      List.exists (fun e ->
        Termops.occur_term sigma e (of_constr c1) ||
        Termops.occur_term sigma e (of_constr c2)) evars) pbs

  let funs = [|
    (fun _-> Munify.unify_evar_conv);
    Munify.unify_match;
    Munify.unify_match_nored;
    (fun _ ts env sigma conv_pb t1 t2->
       try
         match evar_conv_x ts env sigma conv_pb t1 t2 with
         | Success sigma -> Success (consider_remaining_unif_problems env sigma)
         | e -> e
       with _ -> UnifFailure (sigma, Pretype_errors.ProblemBeyondCapabilities))
  |]

  let unicoq_pos = 0
  let evarconv_pos = Array.length funs -1

  (** unify oevars sigma env strategy conv_pb t1 t2 unifies t1 and t2
      according to universe restrictions conv_pb (CUMUL or CONV) and
      strategy (UniCoq,UniMatch,UniMatchNoRed,UniEvarconv). In the
      UniMatch and UniMatchNoRed cases, it only instantiates evars in
      the evars set, assuming oevars = Some evars. If oevars = None,
      then the whole set of evars is assumed.  The idea is to avoid
      pattern matching to instantiate external evars. It returns
      Success or UnifFailure and a bool stating if the strategy used
      was one of the Match. *)
  let unify oevars sigma env strategy conv_pb t1 t2 =
    let ts = get_ts env in
    let pos = get_constructor_pos sigma strategy in
    let evars =
      match oevars with
      | Some e -> e
      | _ -> Evar.Map.domain (Evd.undefined_map sigma) in
    (funs.(pos) evars ts env sigma conv_pb t1 t2,
     pos > unicoq_pos && pos < evarconv_pos)

end

module ExistentialSet = Evar.Set

type elem = (evar_map * constr)

type data =
  | Val of elem
  | Err of elem

let (>>=) v g =
  match v with
  | Val v' -> g v'
  | _ -> v

let return s t = Val (s, t)

let fail s t = Err (s, t)

let print env sigma s =
  Feedback.msg_notice (app (str "[DEBUG] ")
                         (str (CoqString.from_coq (env, sigma) s)))

let mysubstn sigma t n c =
  let rec substrec in_arr depth c = match kind sigma c with
    | Rel k    ->
        if k<=depth then c
        else if k = depth+n then
          Vars.lift depth t
        else mkRel (k+1)
    | _ -> map_with_binders sigma succ (substrec in_arr) depth c in
  substrec false 0 c

let name_occurn_env env n =
  let open Context.Named.Declaration in
  let ids = Environ.fold_named_context_reverse
              (fun s n' -> Id.Set.add (get_id n') s)
              ~init:Id.Set.empty env in (* compute set of ids in env *)
  let ids = Id.Set.remove n ids in (* remove n *)
  let ids = Environ.really_needed env ids in (* and compute closure of ids *)
  Id.Set.mem n ids (* to finally check if n is in it *)

let dest_Case (env, sigma) t =
  let sigma, dyn = mkdyn sigma env in
  try
    let (info, return_type, discriminant, branches) = destCase sigma t in
    let sigma, branch_dyns = Array.fold_right (
      fun t (sigma,l) ->
        let dyn_type = Retyping.get_type_of env sigma t in
        let sigma, cdyn = mkDyn dyn_type t sigma env in
        CoqList.mkCons sigma env dyn cdyn l
    ) branches (CoqList.mkNil sigma env dyn) in
    let ind_type = Retyping.get_type_of env sigma discriminant in
    let return_type_type = Retyping.get_type_of env sigma return_type in
    let sigma, ret_dyn = mkDyn return_type_type return_type sigma env in
    Some (mkCase ind_type discriminant ret_dyn branch_dyns sigma env)
  with
  | Not_found ->
      Exceptions.block "Something specific went wrong. TODO: find out what!"
  | Term.DestKO ->
      None
  | _ ->
      Exceptions.block "Something not so specific went wrong."

let make_Case (env, sigma) case =
  let open Lazy in
  let (_, args) = decompose_appvect sigma case in
  let repr_ind = args.(0) in
  let repr_val = args.(1) in
  let repr_return = get_elem sigma args.(2) in
  let sigma, repr_branches = CoqList.from_coq_conv sigma env (fun sigma x -> sigma, get_elem sigma x) args.(3) in
  let t_type, l = decompose_appvect sigma repr_ind in
  if isInd sigma t_type then
    match kind sigma t_type with
    | Ind ((mind, ind_i), _) ->
        let case_info = Inductiveops.make_case_info env (mind, ind_i) LetPatternStyle in
        let match_term = EConstr.mkCase (case_info, repr_return, repr_val,
                                         (Array.of_list repr_branches)) in
        let match_type = Retyping.get_type_of env sigma match_term in
        mkDyn match_type match_term sigma env
    | _ -> assert false
  else
    Exceptions.block "case_type is not an inductive type"


let get_Constrs (env, sigma) t =
  (* let t = to_constr sigma t in *)
  let t_type, args = decompose_app sigma ((* of_constr @@ *) RE.whd_betadeltaiota env sigma t) in
  if isInd sigma t_type then
    let (mind, ind_i), _ = destInd sigma t_type in
    let mbody = Environ.lookup_mind mind env in
    let ind = Array.get (mbody.mind_packets) ind_i in
    let sigma, dyn = mkdyn sigma env in
    let args = CList.firstn mbody.mind_nparams_rec args in
    let sigma, l = Array.fold_right
                     (fun i (sigma, l) ->
                        let constr = Names.ith_constructor_of_inductive (mind, ind_i) i in
                        let coq_constr = applist (mkConstruct constr, args) in
                        let ty = Retyping.get_type_of env sigma coq_constr in
                        let sigma, dyn_constr = mkDyn ty coq_constr sigma env in
                        CoqList.mkCons sigma env dyn dyn_constr l
                     )
                     (* this is just a dirty hack to get the indices of constructors *)
                     (Array.mapi (fun i t -> i+1) ind.mind_consnames)
                     (CoqList.mkNil sigma env dyn)
    in
    let indty = applist (t_type, args) in
    let indtyty = Retyping.get_type_of env sigma indty in
    let sigma, indtydyn = mkDyn indtyty indty sigma env in
    let sigma, listty = CoqList.mkType sigma env dyn in
    let sigma, pair = CoqPair.mkPair sigma env dyn listty indtydyn l in
    (sigma, pair)
  else
    Exceptions.block "The argument of Mconstrs is not an inductive type"

module Hypotheses = struct

  let ahyp_constr = mkUBuilder "ahyp"

  let mkAHyp sigma env ty n t =
    let sigma, t = match t with
      | None -> CoqOption.mkNone sigma env ty
      | Some t -> CoqOption.mkSome sigma env ty t
    in UConstrBuilder.build_app ahyp_constr sigma env [|ty; n; t|]

  let mkHypType = mkUConstr "Hyp"

  let cons_hyp ty n t renv sigma env =
    let (sigma, hyptype) = mkHypType sigma env in
    let sigma, hyp = mkAHyp sigma env ty n t in
    CoqList.mkCons sigma env hyptype hyp renv

  exception NotAVariable
  exception NotAHyp
  let from_coq (env, sigma as ctx) c =
    let fvar = fun c ->
      if isVar sigma c then c
      else raise NotAVariable
    in
    let fdecl = CoqOption.from_coq sigma env in
    let oargs = UConstrBuilder.from_coq ahyp_constr ctx c in
    match oargs with
    | Some args -> (fvar args.(1), fdecl args.(2), args.(0))
    | None -> raise NotAHyp

  let from_coq_list (env, sigma as ctx) t =
    (* safe to throw away sigma here as it doesn't change *)
    snd (CoqList.from_coq_conv sigma env (fun sigma x -> sigma, from_coq (env, sigma) x ) t)

end

(* It replaces each ii by ci in l = [(i1,c1) ... (in, cn)] in c.
   It throws Not_found if there is a variable not in l *)
let multi_subst sigma l c =
  let rec substrec depth c = match kind sigma c with
    | Rel k    ->
        if k<=depth then c
        else
          List.assoc (k - depth) l
    | _ -> map_with_binders sigma succ substrec depth c in
  substrec 0 c

let name_depends_on sigma deps ty ot =
  let open Idset in let open Termops in
  let vars = collect_vars sigma ty in
  let vars = if Option.has_some ot then
      union (collect_vars sigma (Option.get ot)) vars
    else vars in
  not (is_empty (inter vars deps))

(* given a named_context env and a variable x it returns all the
   (named) variables that depends transitively on x *)
let depends_on env sigma x =
  let open Idset in let open Context.Named in
  let deps = singleton x in
  fold_outside (fun v deps->
    let (n, ot, ty) = Declaration.to_tuple v in
    if name_depends_on sigma deps ty ot then
      Idset.add n deps
    else
      deps) env ~init:deps

let name_deps env x = depends_on (named_context env) x

let compute_deps env sigma x =
  if isVar sigma x then
    let name = destVar sigma x in
    name_deps env sigma name
  else
    failwith "check_dependencies should not be called with not a var or rel"

(* given a rel or var x and a term t and its type ty, it checks if t or ty does not depend on x *)
let check_abs_deps env sigma x t ty =
  let ndeps = compute_deps env sigma x in
  let open Idset in
  is_empty ndeps ||
  (* The term might depend on x, which by invariant we now is a
     variable (since ndeps is not empty) *)
  (subset (inter (collect_vars sigma t) ndeps) (singleton (destVar sigma x)) &&
   is_empty (inter (collect_vars sigma ty) ndeps))

(* check if x \not\in FV(t) union FV(env) *)
let check_dependencies env sigma x t =
  if isVar sigma x then
    let name = destVar sigma x in
    not (Termops.occur_var env sigma name t) && not (name_occurn_env env name)
  else
    failwith "check_dependencies should not be called with not a var or rel"


(** Abstract *)
type abs = AbsProd | AbsFun | AbsLet | AbsFix

let rec n_prods env sigma ty = function
  | 0 -> true
  | n ->
      let ty = (* of_constr @@ *) RE.whd_betadeltaiota env sigma ((* to_constr sigma *) ty) in
      if isProd sigma ty then
        let _, _, b = destProd sigma ty in
        n_prods env sigma b (n-1)
      else
        false

(* abs case env a p x y n abstract variable x from term y according to the case.
   if variables depending on x appear in y or the type p, it fails. n is for fixpoint. *)
let abs case (env, sigma) a p x y n t : data =
  (* check if the type p does not depend of x, and that no variable
     created after x depends on it.  otherwise, we will have to
     substitute the context, which is impossible *)
  let a = nf_evar sigma a in
  let p = nf_evar sigma p in
  let x = nf_evar sigma x in
  let y = nf_evar sigma y in
  if isVar sigma x then
    if check_abs_deps env sigma x y p then
      let name = destVar sigma x in
      let y' = Vars.subst_vars [name] y in
      let t =
        match case with
        | AbsProd -> mkProd (Name name, a, y')
        | AbsFun  -> mkLambda (Name name, a, y')
        | AbsLet  -> mkLetIn (Name name, t, a, y')
        | AbsFix  -> mkFix (([|n-1|], 0), ([|Name name|], [|a|], [|y'|]))
      in
      return sigma t
    else
      Err (E.mkAbsDependencyError sigma env ())
  else
    Err (E.mkNotAVar sigma env ())

(** checks if (option) definition od and type ty has named
    vars included in vars *)
let check_vars sigma od ty vars =
  Idset.subset (Termops.collect_vars sigma ty) vars &&
  if Option.has_some od then
    Idset.subset (Termops.collect_vars sigma (Option.get od)) vars
  else true

exception MissingDep

(* returns a substitution and an environment such that applying
   the substitution to a term makes the term well typed in the environment *)
let new_env (env, sigma) hyps =
  let _, _, subs, env =
    List.fold_right (fun (var, odef, ty) (idlist, idset, subs, env') ->
      (* the definition might refer to previously defined indices
         so we perform the substitution *)
      let odef =
        try Option.map (multi_subst sigma subs) odef
        with Not_found -> raise MissingDep
      in
      (* if the variable is named, its type can only refer to named variables.
         note that typing ensures the var has type ty, so its type must
         be defined in the named context *)
      if check_vars sigma odef ty idset then
        let id = destVar sigma var in
        (id::idlist, Idset.add id idset, subs, push_named (Context.Named.Declaration.of_tuple (id, odef, ty)) env')
      else
        raise MissingDep
    ) hyps ([], Idset.empty, [], empty_env)
  in subs, env

let make_evar sigma env ty =
  if isSort sigma ty && ty <> mkProp then
    let sigma, (evar, _) = Evarutil.new_type_evar env sigma Evd.UnivRigid in
    sigma, evar
  else
    let sigma, evar = Evarutil.new_evar env sigma ty in
    sigma, evar

let cvar (env, sigma as ctx) ty ohyps =
  let ohyps = CoqOption.from_coq sigma env ohyps in
  if Option.has_some ohyps then
    try
      let hyps = Hypotheses.from_coq_list (env, sigma) (Option.get ohyps) in
      let vars = List.map (fun (v, _, _)->v) hyps in
      if List.distinct vars then
        try
          let subs, env = new_env ctx hyps in
          let ty = multi_subst sigma subs ty in
          let sigma, evar = make_evar sigma env ty in
          let (e, _) = destEvar sigma evar in
          (* the evar created by make_evar has id in the substitution
             but we need to remap it to the actual variables in hyps *)
          return sigma (mkEvar (e, Array.of_list vars))
        with
        | MissingDep ->
            Err (E.mkHypMissesDependency sigma env ())
        | Not_found ->
            Err (E.mkTypeMissesDependency sigma env ())
      else
        Err (E.mkDuplicatedVariable sigma env ())
    with Hypotheses.NotAVariable ->
      Err (E.mkNotAVar sigma env ())
  else
    let sigma, evar = make_evar sigma env ty in
    return sigma evar


let get_name (env, sigma) (t: constr) : constr option =
  (* If t is a defined variable it is reducing it *)
  (*  let t = whd_betadeltaiota_nolet env sigma t in *)
  let name =
    if isVar sigma t then Some (Name (destVar sigma t))
    else if isLambda sigma t then
      let (n, _, _) = destLambda sigma t in Some n
    else if isProd sigma t then
      let (n, _, _) = destProd sigma t in Some n
    else if isLetIn sigma t then
      let (n, _, _, _) = destLetIn sigma t in Some n
    else None
  in
  match name with
  | Some (Name i) -> Some (CoqString.to_coq (Names.Id.to_string i))
  | Some _ -> (* it is Anonymous. We generate a fresh name. *)
      let n = Namegen.next_name_away (Name (Names.Id.of_string "x")) (ids_of_context env) in
      Some (CoqString.to_coq (Names.Id.to_string n))
  | _ -> None

(* return the reflected hash of a term *)
let hash env sigma c size =
  let size = CoqN.from_coq (env, sigma) size in
  let h = Term.hash_constr (to_constr sigma c) in
  CoqN.to_coq (Pervasives.abs (h mod size))

(* reflects the hypotheses in [env] in a list of [ahyp] *)
let build_hypotheses sigma env =
  let open Context.Named.Declaration in
  let renv = List.map (fun v->let (n, t, ty) = to_tuple v in (mkVar n, t, ty))
               (named_context env) in
  (* the list is reversed: [H : x > 0, x : nat] *)
  let rec build renv =
    match renv with
    | [] -> let (sigma, ty) = Hypotheses.mkHypType sigma env in
        (CoqList.mkNil sigma env ty)
    | (n, t, ty) :: renv ->
        let (sigma, r) = build renv in
        Hypotheses.cons_hyp ty n t r sigma env
  in
  build renv

(* builds the context without x (which should be a variable) *)
let env_without sigma env renv x =
  let open Context.Named.Declaration in
  let name_env = named_context env in
  let env = Environ.reset_context env in
  let nx = destVar sigma x in
  let name_env = List.filter (fun decl -> get_id decl <> nx) name_env in
  let env = push_named_context name_env env in
  env, build_hypotheses sigma env (* TODO: we should do something smarter here, rebuilding everything is costly *)

let is_nu env sigma x nus =
  let open Context.Named.Declaration in
  let env = named_context env in
  let nx = destVar sigma x in
  let rec find env i =
    let decl = List.hd env in
    if get_id decl = nx then
      i
    else
      find (List.tl env) (i+1)
  in
  find env 0 < nus

(** declare a definition *)
exception DischargeLocality

exception UnsupportedDefinitionObjectKind
exception CanonicalStructureMayNotBeOpaque

let run_declare_def env sigma kind name opaque ty bod =
  let open Decl_kinds in
  (* copied from coq 8.6.1 Vernacentries *)
  let fix_exn = Future.fix_exn_of (Future.from_val bod) in
  let no_hook = Lemmas.mk_hook (fun _ _ -> ()) in
  let vernac_definition_hook p = function
    | Coercion -> Class.add_coercion_hook p
    | CanonicalStructure ->
        if opaque then raise CanonicalStructureMayNotBeOpaque else
          Lemmas.mk_hook (fun _ -> Recordops.declare_canonical_structure)
    | SubClass -> Class.add_subclass_hook p
    (* | Instance -> Lemmas.mk_hook (fun local gr -> *)
    (*   let local = match local with | Global -> false | Local -> true | _ -> raise DischargeLocality in *)
    (*   let () = Typeclasses.declare_instance None local gr *)
    (*   in () *)
    (* ) *)
    | Instance
    | IdentityCoercion | Scheme | StructureComponent | Fixpoint ->
        raise UnsupportedDefinitionObjectKind
    | _ ->
        no_hook
  in
  (* copied from coq 8.6.1 Decl_kinds *)
  let kinds = [|
    Definition
  ; Coercion
  ; SubClass
  ; CanonicalStructure
  ; Example
  ; Fixpoint
  ; CoFixpoint
  ; Scheme
  ; StructureComponent
  ; IdentityCoercion
  ; Instance
  ; Method|]
  in
  let ctx = Evd.universe_context_set sigma in
  let kind_pos = get_constructor_pos sigma kind in
  let kind = kinds.(kind_pos) in
  let name = CoqString.from_coq (env, sigma) name in
  let id = Names.Id.of_string name in
  let kn = Declare.declare_definition ~opaque:opaque ~kind:kind id ~types:ty (bod, ctx) in
  let gr = Globnames.ConstRef kn in
  let () = Lemmas.call_hook fix_exn (vernac_definition_hook false kind) Global gr  in
  let c = (Universes.constr_of_global gr) in
  (* Feedback.msg_notice *)
  (*   (Termops.print_constr_env env c); *)
  (sigma, c)

(** declare implicits *)
let run_declare_implicits env sigma gr impls =
  (* we expect each item in the list to correspond to an optional element of an inductive type roughly like this:
     | Explicit
     | Implicit
     | MaximallyImplicit

     But we do not care much for the actual type so right now we just take the constructor_pos
  *)
  let impliciteness = [|
    (false, false, false)       (* Dummy value *)
  ; (false, true, true)   (* Implicit *)
  ; (true, true, true)    (* Maximal *)
  |]
  in
  let gr = Globnames.global_of_constr gr in
  let impls = CoqList.from_coq sigma env impls in
  let impls = List.rev impls in
  let idx = ref (List.length impls) in
  let impls = List.map
                (fun item ->
                   let kind_pos = get_constructor_pos sigma item in
                   let ret = (if kind_pos > 0 then
                                Some (Constrexpr.ExplByPos(!idx, None), impliciteness.(kind_pos))
                              else
                                None) in
                   (* let ret = match CoqOption.from_coq (env, sigma) item with *)
                   (*   | None -> None *)
                   (*   | Some item -> *)
                   (*       let kind_pos = get_constructor_pos item in *)
                   (*       Some (Constrexpr.ExplByPos(!idx, None), impliciteness.(kind_pos)) *)
                   (* in *)
                   idx := !idx - 1; ret
                ) impls in
  let impls = List.map_filter (fun x -> x) impls in
  (* since there is no way to declare something explicit, we clear implicits first *)
  let () = Impargs.declare_manual_implicits false gr [[]] in
  let () = Impargs.maybe_declare_manual_implicits false gr impls in
  (sigma, CoqUnit.mkTT)



type ctxt = {env: Environ.env; renv: constr; sigma: Evd.evar_map; nus: int; hook: constr option;
             fixpoints: Environ.env;
            }

(* the intention of this function was to add the fixpoint context to the
   normal context for retyping. but it seems unnecessary *)
let get_type_of ctxt t =
  (* let env = push_named_context (named_context ctxt.fixpoints) ctxt.env in *)
  Retyping.get_type_of ctxt.env ctxt.sigma t

let debug = ref false

let rec run' ctxt t =
  let open TConstr in
  let sigma, env = ctxt.sigma, ctxt.env in
  ( match ctxt.hook with
    | Some f ->
        let t = RE.whd_betaiota env sigma t in
        let ty = get_type_of ctxt t in
        run' {ctxt with hook = None} (mkApp (f, [|ty; t|]))
    | None -> return sigma t
  ) >>= fun (sigma, t) ->
  let ctxt = {ctxt with sigma = sigma} in
  (* let t = to_constr sigma t in *)
  let (h, args) = decompose_appvect sigma ((* of_constr @@ *) RE.whd_betadeltaiota_nolet env sigma t) in
  let nth = Array.get args in
  if isLetIn sigma h then
    let open ReductionStrategy in
    let (_, b, _, t) = destLetIn sigma h in
    let (h, args') = decompose_appvect sigma b in
    if isReduce sigma env h && Array.length args' = 3 then
      try
        let b = reduce sigma env (Array.get args' 0) (Array.get args' 2) in
        run' ctxt (mkApp (Vars.subst1 b t, args))
      with RedList.NotAList l ->
        Err (E.mkNotAList sigma env ())
    else
      run' ctxt (mkApp (Vars.subst1 b t, args))
  else
    match h with
    | _ when isret h ->
        return sigma (nth 1)

    | _ when isbind h ->
        run' ctxt (nth 2) >>= fun (sigma', v) ->
        let t' = mkApp(nth 3, [|v|]) in
        run' {ctxt with sigma = sigma'} t'

    | _ when istry' h ->
        begin
          match run' ctxt (nth 1) with
          | Val (sigma, v) -> return sigma v
          | Err (sigma_err, c) ->
              let t' = mkApp(nth 2, [|c|]) in
              (* let sigma = Evd.add_constraints sigma (snd (Evd.universe_context_set sigma_err)) in *)
              let sigma = Evd.set_universe_context sigma (Evd.evar_universe_context sigma_err) in
              (* let sigma, _ = Typing.type_of env sigma t' in *)
              run' {ctxt with sigma=sigma} t'
        end

    | _ when israise h ->
        (* we make sure the exception is a closed term: it does not depend on evars or nus *)
        let term = nth 1 in
        let vars = collect_vars sigma term in
        let nuvars = Context.Named.to_vars (CList.firstn ctxt.nus (named_context env)) in
        let intersect = Id.Set.inter vars nuvars in
        let closed = Id.Set.is_empty intersect && Evar.Set.is_empty (Evarutil.undefined_evars_of_term sigma term) in
        if closed then
          fail sigma (Evarutil.nf_evar sigma term)
        else
          Err (E.mkExceptionNotGround sigma env ())

    | _ when isfix1 h ->
        let a, b, f, x = nth 0, nth 1, nth 2, nth 3 in
        run_fix ctxt h [|a|] b f [|x|]

    | _ when isfix2 h ->
        let a1, a2, b, f, x1, x2 =
          nth 0, nth 1, nth 2, nth 3, nth 4, nth 5 in
        run_fix ctxt h [|a1; a2|] b f [|x1; x2|]

    | _ when isfix3 h ->
        let a1, a2, a3, b, f, x1, x2, x3 =
          nth 0, nth 1, nth 2, nth 3, nth 4, nth 5, nth 6, nth 7 in
        run_fix ctxt h [|a1; a2; a3|] b f [|x1; x2; x3|]

    | _ when isfix4 h ->
        let a1, a2, a3, a4, b, f, x1, x2, x3, x4 =
          nth 0, nth 1, nth 2, nth 3, nth 4, nth 5, nth 6, nth 7, nth 8, nth 9 in
        run_fix ctxt h [|a1; a2; a3; a4|] b f [|x1; x2; x3; x4|]

    | _ when isfix5 h ->
        let a1, a2, a3, a4, a5, b, f, x1, x2, x3, x4, x5 =
          nth 0, nth 1, nth 2, nth 3, nth 4, nth 5, nth 6, nth 7, nth 8, nth 9, nth 10, nth 11 in
        run_fix ctxt h [|a1; a2; a3; a4; a5|] b f [|x1; x2; x3; x4; x5|]

    | _ when isis_var h ->
        let e = nth 1 in
        if isVar sigma e then
          return sigma CoqBool.mkTrue
        else
          return sigma CoqBool.mkFalse

    | _ when isnu h ->
        let a, s, ot, f = nth 0, nth 2, nth 3, nth 4 in
        let namestr = CoqString.from_coq (env, sigma) s in
        let name = Names.Id.of_string namestr in
        if Id.Set.mem name (vars_of_env env) then
          Err (Exceptions.mkNameExists sigma env s)
        else begin
          let fx = mkApp(f, [|mkVar name|]) in
          let ot = CoqOption.from_coq sigma env ot in
          let env = push_named (Context.Named.Declaration.of_tuple (name, ot, a)) env in
          let (sigma, renv) = Hypotheses.cons_hyp a (mkVar name) ot ctxt.renv sigma env in
          match run' {ctxt with env; renv; sigma; nus=(ctxt.nus+1)} fx with
          | Val (sigma', e) ->
              if occur_var env sigma' name e then
                Err (E.mkVarAppearsInValue sigma' env ())
              else
                return sigma' e
          | Err (sigma, e) ->
              fail sigma e
        end

    | _ when isabs_fun h ->
        let a, p, x, y = nth 0, nth 1, nth 2, nth 3 in
        abs AbsFun (env, sigma) a p x y 0 mkProp

    | _ when isabs_let h ->
        let a, p, x, t, y = nth 0, nth 1, nth 2, nth 3, nth 4 in
        abs AbsLet (env, sigma) a p x y 0 t

    | _ when isabs_prod h ->
        let a, x, y = nth 0, nth 1, nth 2 in
        (* HACK: put mkProp as returning type *)
        abs AbsProd (env, sigma) a mkProp x y 0 mkProp

    | _ when isabs_fix h ->
        let a, f, t, n = nth 0, nth 1, nth 2, nth 3 in
        let n = CoqN.from_coq (env, sigma) n in
        (* HACK: put mkProp as returning type *)
        abs AbsFix (env, sigma) a mkProp f t n mkProp

    | _ when isget_binder_name h ->
        let t = nth 1 in
        let s = get_name (env, sigma) t in
        begin
          match s with
          | Some s -> return sigma s
          | None ->
              Err (Exceptions.mkWrongTerm sigma env ())
        end

    | _ when isremove h ->
        let x, t = nth 2, nth 3 in
        if isVar sigma x then
          if check_dependencies env sigma x t then
            let nus = if is_nu env sigma x ctxt.nus then ctxt.nus-1 else ctxt.nus in
            let env, (sigma, renv) = env_without sigma env ctxt.renv x in
            run' {ctxt with env; renv; sigma; nus} t
          else
            Err (E.mkCannotRemoveVar sigma env x)
        else
          Err (E.mkNotAVar sigma env ())

    | _ when isgen_evar h->
        let ty, hyp = nth 0, nth 1 in
        cvar (env, sigma) ty hyp

    | _ when isis_evar h ->
        let e = whd_evar sigma (nth 1) in
        if isEvar sigma e || (isApp sigma e && isEvar sigma (fst (destApp sigma e))) then
          return sigma CoqBool.mkTrue
        else
          return sigma CoqBool.mkFalse

    | _ when ishash h ->
        return sigma (hash env sigma (nth 1) (nth 2))

    | _ when issolve_typeclasses h ->
        let evd' = Typeclasses.resolve_typeclasses ~fail:false env sigma in
        return evd' CoqUnit.mkTT

    | _ when isprint h ->
        let s = nth 0 in
        print env sigma s;
        return sigma CoqUnit.mkTT

    | _ when ispretty_print h ->
        let t = nth 1 in
        let t = nf_evar sigma t in
        let s = constr_to_string_env sigma env t in
        return sigma (CoqString.to_coq s)

    | _ when ishyps h ->
        return sigma ctxt.renv

    | _ when isdestcase h ->
        let t = nth 1 in
        begin
          match dest_Case (env, sigma) t with
          | Some (sigma', case) -> return sigma' case
          | _ -> Err (E.mkNotAMatchExp sigma env ())
        end

    | _ when isconstrs h ->
        let t = nth 1 in
        let (sigma', constrs) = get_Constrs (env, sigma) t in
        return sigma' constrs

    | _ when ismakecase h ->
        let case = nth 0 in
        begin
          try
            let (sigma', case) = make_Case (env, sigma) case in
            return sigma' case
          with CoqList.NotAList l ->
            Err (E.mkNotAList sigma env ())
        end

    | _ when isunify h ->
        let a, x, y, uni = nth 0, nth 1, nth 2, nth 3 in
        let sigma, feqT = CoqEq.mkType sigma env a x y in
        begin
          let r = UnificationStrategy.unify None sigma env uni Reduction.CONV x y in
          match r with
          | Evarsolve.Success sigma, _ ->
              let sigma, feq = CoqEq.mkEqRefl sigma env a x in
              let sigma, someFeq = CoqOption.mkSome sigma env feqT feq in
              return sigma someFeq
          | _, _ ->
              let sigma, none = CoqOption.mkNone sigma env feqT in
              return sigma none
        end

    | _ when isunify_univ h ->
        let x, y, uni = nth 0, nth 1, nth 2 in
        let fT = mkProd(Name.Anonymous, x, y) in
        begin
          let r = UnificationStrategy.unify None sigma env uni Reduction.CUMUL x y in
          match r with
          | Evarsolve.Success sigma, _ ->
              let id = mkLambda(Name.Anonymous,x,mkRel 1) in
              let sigma, some = CoqOption.mkSome sigma env fT id in
              return sigma some
          | _, _ ->
              let sigma, none = CoqOption.mkNone sigma env fT in
              return sigma none
        end

    | _ when isget_reference h ->
        let s = CoqString.from_coq (env, sigma) (nth 0) in
        let open Nametab in let open Libnames in
        begin
          try
            let sigma, v = Evd.fresh_global env sigma (locate (qualid_of_string s)) in
            let ty = Retyping.get_type_of env sigma (of_constr v) in
            let sigma, dyn = mkDyn ty (of_constr v) sigma env in
            return sigma dyn
          with _ -> Err (Exceptions.mkRefNotFound sigma env s)
        end

    | _ when isget_var h ->
        let s = CoqString.from_coq (env, sigma) (nth 0) in
        let open Context.Named in
        begin
          try
            let var = lookup (Id.of_string s) (named_context env) in
            let sigma, dyn = mkDyn (Declaration.get_type var) (mkVar (Declaration.get_id var)) sigma env in
            return sigma dyn
          with _ -> Err (Exceptions.mkRefNotFound sigma env s)
        end

    | _ when iscall_ltac h ->
        let concl, name, args = nth 0, nth 1, nth 2 in
        let name, args = CoqString.from_coq (env, sigma) name, CoqList.from_coq sigma env args in
        (* let name = Lib.make_kn (Names.Id.of_string name) in *)
        (* let tac = Tacenv.interp_ml_tactic name in *)
        let tac =
          let rec aux = function
            | [] -> raise Not_found
            | (k, _)::_ when String.equal (Names.KerName.to_string k) name ->
                let args =
                  let aux x =
                    let x = CoqSig.from_coq (env, sigma) x in
                    let x = Detyping.detype false [] env sigma x in
                    Tacexpr.ConstrMayEval (Genredexpr.ConstrTerm (x (*Glob_term.GVar (Loc.ghost, Term.destVar x*), None))
                  in
                  List.map aux args
                in
                Tacexpr.TacArg (Loc.tag (Tacexpr.TacCall (Loc.tag (Misctypes.ArgArg (Loc.tag k), args))))
            | (k, _)::xs -> aux xs
          in
          aux (KNmap.bindings (Tacenv.ltac_entries ()))
        in
        begin
          try
            let undef = Evar.Map.domain (Evd.undefined_map sigma) in
            let (c, sigma) = Pfedit.refine_by_tactic env sigma concl (Tacinterp.eval_tactic tac) in
            let new_undef = Evar.Set.diff (Evar.Map.domain (Evd.undefined_map sigma)) undef in
            let new_undef = Evar.Set.elements new_undef in
            let sigma, goal = Goal.mkgoal sigma env in
            let sigma, goals = CoqList.pto_coq env goal (fun e sigma->Goal.goal_of_evar env sigma e) new_undef sigma in
            let sigma, pair = CoqPair.mkPair sigma env concl goal (of_constr c) goals in
            return sigma pair
          with CErrors.UserError(s,ppm) ->
            let expl = string_of_ppcmds ppm in
            let s = Option.default "" s in
            Err (Exceptions.mkLtacError sigma env (s ^ ": " ^ expl))
             | e ->
                 Err (Exceptions.mkLtacError sigma env (Printexc.to_string e))
        end
    (* Tac (sigma, Tacinterp.eval_tactic tac, fun v -> Val v) *)

    | _ when islist_ltac h ->
        let aux k _ = Feedback.msg_info (Pp.str (Names.KerName.to_string k)) in
        KNmap.iter aux (Tacenv.ltac_entries ());
        return sigma CoqUnit.mkTT

    | _ when isread_line h ->
        return sigma (CoqString.to_coq (read_line ()))

    | _ when isbreak h ->
        run' {ctxt with hook=Some (nth 0)} (nth 2)(*  >>= fun (sigma, _) -> *)
    (* return sigma CoqUnit.mkTT *)

    | _ when isdecompose h ->
        let (h, args) = decompose_app sigma (nth 1) in
        let sigma, dyn = mkdyn sigma env in
        let sigma, listdyn = CoqList.mkType sigma env dyn in
        let sigma, dh = mkDyn (Retyping.get_type_of env sigma h) h sigma env in
        let sigma, args = CoqList.pto_coq env dyn (fun t sigma->mkDyn (Retyping.get_type_of env sigma t) t sigma env) args sigma in
        let sigma, pair =CoqPair.mkPair sigma env dyn listdyn dh args in
        return sigma pair

    | _ when issolve_typeclass h ->
        let ty = nth 0 in
        begin
          try
            let sigma, v = Typeclasses.resolve_one_typeclass ~unique:false env sigma  ty in
            let sigma, some = (CoqOption.mkSome sigma env ty v) in
            return sigma some
          with Not_found ->
            let sigma, none = (CoqOption.mkNone sigma env ty) in
            return sigma none
        end

    | _ when isdeclare h ->
        let kind, name, opaque, ty, bod = nth 0, nth 1, nth 2, nth 3, nth 4 in
        (try
           let ty = to_constr sigma ty in
           let bod = to_constr sigma bod in
           let sigma, ret = run_declare_def env sigma kind name (CoqBool.from_coq sigma opaque) ty bod in
           return sigma (of_constr ret)
         with
         | CErrors.AlreadyDeclared _ ->
             Err (E.mkAlreadyDeclared sigma env name)
         | Type_errors.TypeError(env, Type_errors.UnboundVar _) ->
             Err (E.mkTypeErrorUnboundVar sigma env ())
        )

    | _ when isdeclare_implicits h ->
        let reference, impls = (*nth 0 is the type *) nth 1, nth 2 in
        (try
           let reference = to_constr sigma reference in
           let sigma, ret = run_declare_implicits env sigma reference impls in
           return sigma ret
         with Not_found ->
           Err (E.mkNotAReference sigma env (nth 0) reference)
        )

    | _ when isos_cmd h ->
        let cmd = CoqString.from_coq (env, sigma) (nth 0) in
        let ret = Sys.command cmd in
        return sigma (CoqZ.to_coq ret)

    | _ when isget_debug h ->
        return sigma (CoqBool.to_coq !debug)
    | _ when isset_debug h ->
        debug := CoqBool.from_coq sigma (nth 0);
        return sigma CoqUnit.mkTT

    | _ ->
        begin
          try
            let n = EConstr.destVar sigma h in
            match Environ.named_body n ctxt.fixpoints with
            | Some fixbody ->
                let t = (EConstr.applist (of_constr fixbody,Array.to_list args)) in
                run' ctxt t
            | None -> Err (E.mkStuckTerm sigma env ())
          with | Term.DestKO ->
            Err (E.mkStuckTerm sigma env ())
        end

(* h is the mfix operator, a is an array of types of the arguments, b is the
   return type of the fixpoint, f is the function
   and x its arguments. *)
and run_fix ctxt (h: constr) (a: constr array) (b: constr) (f: constr) (x: constr array) =
  (* let fixbody = mkApp(h, Array.append a [|b;s;i|]) in *)
  (* run' ctxt c *)
  let sigma, env = ctxt.sigma, ctxt.env in
  (* let fix_type = Retyping.get_type_of env sigma fixbody in *)
  let name =
    if isVar sigma f then Some (Name (destVar sigma f))
    else if isLambda sigma f then
      let (n, _, _) = destLambda sigma f in Some n
    else if isProd sigma f then
      let (n, _, _) = destProd sigma f in Some n
    else if isLetIn sigma f then
      let (n, _, _, _) = destLetIn sigma f in Some n
    else None
  in
  let name = match name with | Some (Name i) -> Names.Id.to_string i | Some _ -> "anon" | None -> "impossible" in

  let n = Namegen.next_name_away (Name (Names.Id.of_string (concat "mtac_fix_" [name]))) (ids_of_context env) in
  (* let env = push_named (Context.Named.Declaration.of_tuple (n, None, fix_type)) env in *)
  let fixvar = EConstr.mkVar n in
  let fixf = mkApp(f, [|fixvar|]) in
  (* HACK: we put Prop as the type of fixf in the context, simply because we
     don't care. If it turns out to be problematic, we have to construct its
     type. *)
  let fixpoints = push_named (Context.Named.Declaration.of_tuple (n, Some (fixf), EConstr.mkProp)) ctxt.fixpoints in
  let c = mkApp (f, Array.append [| fixvar |] x) in
  run' {ctxt with sigma=sigma; env=env; fixpoints=fixpoints} c
(* run' ctxt c *)

(* Takes a [sigma], a set of evars [metas], and a [term],
   and garbage collects all the [metas] in [sigma] that do not appear in
   [term]. *)
let clean_unused_metas sigma metas term =
  let rec rem (term : constr) (metas : ExistentialSet.t) =
    let fms = Evd.evars_of_term (to_constr sigma term) in
    let metas = ExistentialSet.diff metas fms in
    (* we also need to remove all metas that occur in the
       types, context, and terms of other metas *)
    ExistentialSet.fold (fun ev metas ->
      let ev_info = Evd.find sigma ev  in
      let metas = rem (of_constr @@ Evd.evar_concl ev_info) metas in
      let metas = List.fold_right (fun var metas ->
        let (_, body, ty) = Context.Named.Declaration.to_tuple var in
        let metas = rem ty metas in
        match body with
        | None -> metas
        | Some v -> rem v metas) (List.map of_named_decl @@ Evd.evar_context ev_info) metas in
      match Evd.evar_body ev_info with
      | Evar_empty -> metas
      | Evar_defined b -> rem (of_constr b) metas
    ) fms metas
  in
  let metas = rem term metas in
  (* remove all the reminding metas, also from the future goals *)
  let sigma = ExistentialSet.fold
                (fun ev sigma -> Evd.remove sigma ev) metas sigma in
  let future_goals = Evd.future_goals sigma in
  let principal_goal = Evd.principal_future_goal sigma in
  let sigma = Evd.reset_future_goals sigma in
  let alive = List.filter (fun e->not (ExistentialSet.mem e metas)) future_goals in
  let principal_goal =
    match principal_goal with
    | Some e ->
        if not (ExistentialSet.mem e metas) then
          Some e
        else
          None
    | None -> None
  in
  Evd.restore_future_goals sigma alive principal_goal


(* returns the enviornment and substitution without db rels *)
let db_to_named sigma env =
  let open Context in
  let env' = push_named_context (named_context env) (reset_context env) in
  let vars = Id.Set.elements (Named.to_vars (named_context env)) in
  let _, subs, env = CList.fold_right_i (fun n var (vars, subs, env') ->
    (* the definition might refer to previously defined indices
       so we perform the substitution *)
    let (name, odef, ty) = Rel.Declaration.to_tuple var in
    let odef = Option.map (multi_subst sigma subs) odef in
    let ty = multi_subst sigma subs ty in
    (* since the name can be Anonymous, we need to generate a name *)
    let id =
      match name with
      | Anonymous ->
          Id.of_string ("_MC" ^ string_of_int n)
      | Name n ->
          Namegen.next_name_away name vars in
    let nvar = Named.Declaration.of_tuple (id, odef, ty) in
    id::vars, (n, mkVar id) :: subs, push_named nvar env'
  ) 1 (rel_context env) (vars, [], env') in
  subs, env

(* It replaces each ci by ii in l = [(i1,c1) ... (in, cn)] in c. *)
let multi_subst_inv sigma l c =
  let l = List.map (fun (a, b) -> (b, a)) l in
  let rec substrec depth c =
    begin
      try let n = destVar sigma c in
        begin
          try mkRel (List.assoc (mkVar n) l + depth)
          with Not_found -> mkVar n
        end
      with | Term.DestKO ->
        map_with_binders sigma succ substrec depth c
    end
  in substrec 0 c


let run (env0, sigma) t =
  let subs, env = db_to_named sigma env0 in
  let t = multi_subst sigma subs t in
  let (sigma, renv) = build_hypotheses sigma env in
  match run' {env; renv; sigma; nus=0;hook=None; fixpoints=Environ.empty_env} t with
  | Err (sigma', v) ->
      (* let v = Vars.replace_vars vsubs v in *)
      let v = multi_subst_inv sigma' subs v in
      let sigma', _ = Typing.type_of env0 sigma' v in
      Err (sigma', v)
  | Val (sigma', v) ->
      let v = multi_subst_inv sigma' subs v in
      let sigma', _ = Typing.type_of env0 sigma' v in
      Val (sigma', v)

(** set the run function in unicoq *)
let _ = Munify.set_lift_constr (fun env sigma -> (MetaCoqNames.mkUConstr "lift" sigma env))
let _ = Munify.set_run (fun env sigma t ->
  match run (env, sigma) t with
  | Err _ -> None
  | Val c -> Some c)
