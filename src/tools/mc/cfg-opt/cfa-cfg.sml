(* cfa-cfg.sml
 *
 * COPYRIGHT (c) 2007 The Manticore Project (http://manticore.cs.uchicago.edu)
 * All rights reserved.
 *)

structure CFACFG : sig

    val analyze : CFG.module -> unit

    datatype call_sites
      = Unknown				(* possible unknown call sites *)
      | Known of CFG.Label.Set.set	(* only called from known locations; the labels *)
                                        (* are the entry labels of the functions that call *)
                                        (* the target *)

    val callSitesOf : CFG.label -> call_sites

    datatype value
      = TOP
      | TUPLE of value list
      | LABELS of CFG.Label.Set.set
      | BOT

    val valueOf : CFG.var -> value

  (* return the set of labels that a control transfer targets; the empty set
   * is used to represent unknown control flow.
   *)
    val labelsOf : CFG.transfer -> CFG.Label.Set.set

  (* return true if the given label escapes *)
    val isEscaping : CFG.label -> bool

    val clearInfo : CFG.module -> unit

  end = struct

    val debugFlg = ref false
    val resultsFlg = ref false
    val oldAnalFlg = ref false
    val () = List.app (fn ctl => ControlRegistry.register CFGOptControls.registry {
	      ctl = Controls.stringControl ControlUtil.Cvt.bool ctl,
	      envName = NONE
	    }) [
	      Controls.control {
		  ctl = debugFlg,
		  name = "cfa-debug",
		  pri = [0, 1],
		  obscurity = 0,
		  help = "debug cfa"
		},
	      Controls.control {
		  ctl = resultsFlg,
		  name = "cfa-results",
		  pri = [0, 1],
		  obscurity = 0,
		  help = "print results of cfa"
		},
	      Controls.control {
		  ctl = oldAnalFlg,
		  name = "cfa-old-anal",
		  pri = [0, 1],
		  obscurity = 0,
		  help = "repeatedly analyze blocks at transfers"
		}
	    ]

    structure LSet = CFG.Label.Set

    datatype call_sites
      = Unknown			(* possible unknown call sites *)
      | Known of LSet.set	(* only called from known locations; the labels are the *)
				(* entry labels of the functions that call the target *)

    fun callSitesToString v = let
	  fun v2s (Unknown, l) = "?" :: l
	    | v2s (Known s, l) = let
		fun f [] = "}" :: l
		  | f [x] = "$" :: CFG.Label.toString x :: "}" :: l
		  | f (x::r) = "$" :: CFG.Label.toString x :: "," :: f r
		in
		  "{" :: f (LSet.listItems s)
		end
	  in
	    concat (v2s(v, []))
	  end

    datatype value
      = TOP
      | TUPLE of value list
      | LABELS of LSet.set
      | BOT

    fun valueToString v = let
	  fun v2s (TOP, l) = "T" :: l
	    | v2s (TUPLE[], l) = "()" :: l
	    | v2s (TUPLE[v], l) = "(" :: v2s (v, ")" :: l)
	    | v2s (TUPLE(v::r), l) =
		"(" :: v2s (v, List.foldr (fn (v, l) => "," :: v2s(v, l)) (")" :: l) r)
	    | v2s (LABELS s, l) = let
		fun f [] = "}" :: l
		  | f [x] = "$" :: CFG.Label.toString x :: "}" :: l
		  | f (x::r) = "$" :: CFG.Label.toString x :: "," :: f r
		in
		  "{" :: f (LSet.listItems s)
		end
	    | v2s (BOT, l) = "#" :: l
	  in
	    concat (v2s(v, []))
	  end

  (* property to track call-sites *)
    val {getFn=getSites, clrFn=clrSites, setFn=setSites, ...} =
	  CFG.Label.newProp (fn _ => Known(LSet.empty))
    val callSitesOf = getSites
  (* property to track the estimated value of variables *)
    val {getFn=getValue, clrFn=clrValue, peekFn=peekValue, setFn=setValue} =
	  CFG.Var.newProp (fn _ => BOT)
    val valueOf = getValue

  (* return true if the given label escapes *)
    fun isEscaping lab = (case callSitesOf lab of Unknown => true | _ => false)

  (* clear CFA annotations from the variables and labels of a module.  Note that we can
   * restrict the traversal to binding instances.
   *)
    fun clearInfo (CFG.MODULE{code, ...}) = let
	  fun doFunct (CFG.FUNC{lab, entry, body, ...}) = (
		clrSites lab;
		List.app clrValue (CFG.paramsOfConv entry);
		List.app doExp body)
	  and doExp exp = List.app clrValue (CFG.lhsOfExp exp)
	  in
	    List.app doFunct code
	  end

  (* marks on entry labels to avoid infinite loops in the analysis *)
    local
      val {getFn, setFn, ...} = CFG.Label.newProp(fn _ => 0)
    in
    fun isMarked lab = (getFn lab > 0)
    fun mark lab = setFn(lab, getFn lab + 1)
    fun unmark lab = setFn(lab, getFn lab - 1)
    end

  (* test if a new approximate value is different from an old value; this
   * code assumes that values change according to the lattice order.
   *)
    fun changedValue (new, old) = (case (new, old)
	   of (TOP, TOP) => false
	    | (TOP, _) => true
	    | (BOT, BOT) => false
	    | (_, BOT) => true
	    | (TUPLE vs1, TUPLE vs2) => let
		fun changed ([], []) = false
		  | changed (x::xs, y::ys) = changedValue(x, y) orelse changed(xs, ys)
		  | changed (l, []) = true
		  | changed ([], l) = raise Fail "non-monotonic change"
		in
		  changed (vs1, vs2)
		end
	    | (LABELS s1, LABELS s2) => if LSet.isSubset (s2, s1)
		then (LSet.numItems s2 < LSet.numItems s1)
		else raise Fail "non-monotonic change"
	    | _ => raise Fail "type error"
	  (* end case *))

  (* this global reference is used to mark when a value changes during an anlysis pass;
   * it is global (ugh!) because I wanted to lift the escapingValue code out of the
   * main function.
   *)
    val changed = ref false

  (* depth limit on approximate values *)
    val maxDepth = 3

  (* update the approximate value of a variable by some delta and record if
   * it changed.
   *)
    fun addInfo (x, BOT) = ()
      | addInfo (x, v) = (case peekValue x
	   of NONE => (
		changed := true;
		setValue(x, v))
	    | SOME oldV => let
		val newV = joinValues(oldV, v)
		in
		  if changedValue(newV, oldV)
		    then (changed := true; setValue(x, newV))
		    else ()
		end
	  (* end case *))

  (* if a value escapes (e.g., is passed to an escaping function), we need to mark any
   * labels that it contains as escaping too.
  *)
    and escapingValue (LABELS labs) = let
	(* for each escaping function, we set its call site to Unknown and
	 * set its parameters to TOP.
	 *)
	  fun doLab lab = if not(isEscaping lab)
		then (case CFGUtil.funcOfLabel lab
		   of SOME(CFG.FUNC{entry, ...}) => (
			setSites (lab, Unknown);
			List.app (fn x => addInfo(x, TOP)) (CFG.paramsOfConv entry))
		    | _ => ()
		  (* end case *))
		else ()
	  in
	    CFG.Label.Set.app doLab labs
	  end
      | escapingValue (TUPLE vs) = List.app escapingValue vs
      | escapingValue _ = ()

    and joinValues (v1, v2) = let
	  fun kJoin (0, v1, v2) = (
	      (* since the value are going to top, we can't track them so they may be escaping *)
		escapingValue v1; escapingValue v2; TOP)
	    | kJoin (_, TOP, v) = (escapingValue v; TOP)
	    | kJoin (_, v, TOP) = (escapingValue v; TOP)
	    | kJoin (_, BOT, v) = v
	    | kJoin (_, v, BOT) = v
	    | kJoin (k, TUPLE vs1, TUPLE vs2) = let
		fun join ([], []) = []
		  | join (x::xs, y::ys) = kJoin(k-1, x, y) :: join(xs, ys)
		  | join ([], l) = l
		  | join (l, []) = l
		in
		  TUPLE(join(vs1, vs2))
		end
	    | kJoin (_, LABELS labs1, LABELS labs2) = LABELS(LSet.union(labs1, labs2))
	    | kJoin _ = (
	      (* since the value are going to top, we can't track them so they may be escaping *)
		escapingValue v1; escapingValue v2; TOP)
	  in
	    kJoin (maxDepth, v1, v2)
	  end

  (* select the i'th component of a tuple. *)
    fun select (i, y) = (case getValue y
	   of TUPLE vs => let
		fun sel (0, v::_) = v
		  | sel (i, v::r) = sel(i-1, r)
		  | sel (i, []) = BOT (* or should this be TOP? *)
		in
		  sel (i, vs)
		end
	    | BOT => BOT
	    | TOP => TOP
	    | v => raise Fail(concat[
		  "type error: select(", Int.toString i, ", ", CFG.Var.toString y,
		  "); getValue(", CFG.Var.toString y, ") = ", valueToString v
		])
	  (* end case *))
  (* update the i'th component of a tuple. *)
    fun update (i, y, z) = (case getValue y
	   of TUPLE vs => let
		fun upd (0, v::r, ac) = TUPLE ((rev ac) @ (z::r))
		  | upd (0, [], ac) = TUPLE ((rev ac) @ [z])
		  | upd (i, v::r, ac) = upd(i-1, r, v::ac)
		  | upd (i, [], ac) = upd(i-1, [], BOT (* or should this be TOP? *) :: ac)
		in
		  upd (i, vs, [])
		end
	    | BOT => BOT
	    | TOP => (escapingValue z; TOP)
	    | v => raise Fail(concat[
		  "type error: update(", Int.toString i, ", ", CFG.Var.toString y, 
                  ", ", valueToString z,
		  "); getValue(", CFG.Var.toString y, ") = ", valueToString v
		])
	  (* end case *))

(* +DEBUG *)
    fun printResults code = let
          fun printCallSitesOf l =
                print(concat["callSitesOf(", CFG.Label.toString l, ") = ",
                             callSitesToString (getSites l), "\n"])
          fun printValueOf x =
                print(concat["getValue(", CFG.Var.toString x, ") = ",
                             valueToString (getValue x), "\n"])
          fun printExp e = List.app printValueOf (CFG.lhsOfExp e)
          and printFunct (CFG.FUNC{lab, entry, body, ...}) = (
                printCallSitesOf lab;
                List.app printValueOf (CFG.paramsOfConv entry);
                List.app printExp body)
	  in
	    List.app printFunct code
	  end
(* -DEBUG *)

  (* compute the call-sites of labels.  We visit every function and add its label
   * to the call sites of any known targets.  Note that this function is called
   * after the main analysis and that the call site of any escaping function
   * should have been set to Unknown.
   *)
    fun computeCallSites code = let
	  fun compute (CFG.FUNC{lab=srcLab, exit, ...}) = let
		fun add dstLab = (case getSites dstLab
		       of Unknown => ()
			| Known s => setSites(dstLab, Known(LSet.add(s, srcLab)))
		      (* end case *))
		fun addSet f = (case getValue f
		       of LABELS s => LSet.app add s
			| _ => ()
		      (* end case *))
		fun addJump (lab, _) = add lab
		in
		  case exit
		   of CFG.StdApply{f, ...} => addSet f
		    | CFG.StdThrow{k, ...} => addSet k
		    | CFG.Apply{f, ...} => addSet f
		    | CFG.Goto jmp => addJump jmp
		    | CFG.If(_, j1, j2) => (addJump j1; addJump j2)
		    | CFG.Switch(_, cases, dflt) => (
			List.app (addJump o #2) cases;
			Option.app addJump dflt)
		    | CFG.HeapCheck{nogc, ...} => addJump nogc
		    | CFG.AllocCCall{ret, ...} => addJump ret
		  (* end case *)
		end
	  in
	    List.app compute code
	  end

    fun analyze (CFG.MODULE{code, ...}) = let
	  fun onePass () = let
                val () = if !debugFlg 
                           then print(concat["onePass()\n"]) 
                           else ();
		val addInfo = if !debugFlg
		      then (fn (x, v) => let
			val prevV = getValue x
			in
			  addInfo (x, v);
			  if changedValue(getValue x, prevV) 
			    then print(concat[
				"addInfo(", CFG.Var.toString x,  ", ", valueToString v, 
				"): ", valueToString prevV, " ==> ", valueToString(getValue x),
				"\n"
			      ])
			    else ()
			end)
		      else addInfo
                val addInfo' = fn (x, y) => addInfo (x, getValue y)
	      (* record that a given variable escapes *)
		fun escape x = escapingValue (getValue x)
		fun doFunc (f as CFG.FUNC{lab, entry, body, exit}, args) = (
                      if !debugFlg 
                        then print(concat["doFunc(",CFG.Label.toString lab,")\n"]) 
                        else ();
		      ListPair.appEq addInfo' (CFG.paramsOfConv entry, args);
                      if !oldAnalFlg
                        then 
                          if isMarked lab
                            then ()
                            else (
                              mark lab;
                              List.app doExp body;
                              doXfer exit;
                              unmark lab)
                        else 
                          if isMarked lab
                            then ()
                            else (
                              changed := true; 
                              mark lab))
		and doExp (CFG.E_Var(xs, ys)) =
		      ListPair.appEq addInfo' (xs, ys)
		  | doExp (CFG.E_Const (x, _, _)) = addInfo(x, TOP)
		  | doExp (CFG.E_Cast(x, _, y)) = addInfo(x, getValue y)
		  | doExp (CFG.E_Label(x, lab)) = addInfo(x, LABELS(LSet.singleton lab))
		  | doExp (CFG.E_Select(x, i, y)) =
		      addInfo(x, select(i, y))
		  | doExp (CFG.E_Update(i, y, z)) = 
                      (escape z; addInfo(y, update(i, y, getValue z)))
		  | doExp (CFG.E_AddrOf(x, i, y)) = 
                      (addInfo(x, TOP); addInfo(y, update(i, y, TOP)))
		  | doExp (CFG.E_Alloc(x, xs)) = addInfo(x, TUPLE(List.map getValue xs))
		  | doExp (CFG.E_GAlloc(x, xs)) = addInfo(x, TUPLE(List.map getValue xs))
		  | doExp (CFG.E_Promote(x, y)) = addInfo(x, getValue y)
		  | doExp (CFG.E_Prim(x, prim)) = 
                      (if PrimUtil.isPure prim 
                          then ()
                          else List.app escape (PrimUtil.varsOf prim);
                       addInfo(x, TOP))
		  | doExp (CFG.E_CCall(xs, _, args)) = 
                      (List.app escape args; List.app (fn x => addInfo(x, TOP)) xs)
		  | doExp (CFG.E_HostVProc x) = addInfo(x, TOP)
		  | doExp (CFG.E_VPLoad(x, _, vp)) = addInfo(x, TOP)
		  | doExp (CFG.E_VPStore(_, vp, x)) = escape x
		and doXfer (CFG.StdApply{f, clos, args, ret, exh}) =
		      doApply (f, clos :: args @ [ret, exh])
		  | doXfer (CFG.StdThrow{k, clos, args}) = doApply (k, clos :: args)
		  | doXfer (CFG.Apply{f, clos, args}) = doApply (f, clos :: args)
		  | doXfer (CFG.Goto jmp) = doJump jmp
		  | doXfer (CFG.If(_, jmp1, jmp2)) = (doJump jmp1; doJump jmp2)
		  | doXfer (CFG.Switch(x, cases, dflt)) = (
		      List.app (doJump o #2) cases;
		      Option.app doJump dflt)
		  | doXfer (CFG.HeapCheck{nogc, ...}) = doJump nogc
		  | doXfer (CFG.AllocCCall{ret, args, ...}) = (
		      List.app escape args;
		      doJump ret)
		and doJump (lab, args) = (case CFGUtil.funcOfLabel lab
		       of SOME func => doFunc (func, args)
			| _ => raise Fail "jump to unknown label"
		      (* end case *))
		and doApply (f, args) = (case getValue f
		       of LABELS targets => LSet.app (fn lab => doJump(lab, args)) targets
			| BOT => ()
			| TOP => List.app escape args
			| v => raise Fail(concat[
			      "type error: doApply(", CFG.Var.toString f, ", [",
			      String.concatWith "," (List.map CFG.Var.toString args),
			      "]); getValue(", CFG.Var.toString f, ") = ", valueToString v,
			      "\n"
			    ])
		      (* end case *))
	      (* analyse standard functions and continuations *)
		fun doTopFuncA (f as CFG.FUNC{lab, entry, body, exit}) = let
		      fun anal () = (
			    mark lab;
			    List.app doExp body;
			    doXfer exit;
			    unmark lab)
		      in
			case entry
			 of CFG.StdFunc _ => anal()
			  | CFG.StdCont _ => anal()
			  | _ => anal ()
			(* end case *)
		      end
                fun doTopFuncB (f as CFG.FUNC{lab, entry, body, exit}) = let
                      fun anal () = (
                            List.app doExp body;
                            doXfer exit)
                      in
			case entry
			 of CFG.StdFunc _ => anal()
			  | CFG.StdCont _ => anal()
			  | _ => if isMarked lab then anal () else ()
                      end
                val doTopFunc = if !oldAnalFlg then doTopFuncA else doTopFuncB
		in
		  changed := false;
		  List.app doTopFunc code;
		  !changed
		end
	  fun iterate () = if onePass() then iterate() else ()
	  in
	  (* initialize the arguments to the module entry to top *)
	    case code
	     of CFG.FUNC{lab, entry=CFG.StdFunc{clos, args, ret, exh}, ...} :: _ => (
                  setSites (lab, Unknown);
		  setValue (clos, TOP); List.app (fn x => setValue (x, TOP)) args;
		  setValue (ret, TOP); setValue (exh, TOP))
	      | _ => raise Fail "strange module entry"
	    (* end case *);
	  (* iterate to a fixed point *)
	    iterate ();
	  (* compute call-side information for labels *)
	    computeCallSites code;
          (* print results of cfa *)
            if !resultsFlg then printResults code else ()
	  end

  (* return the set of labels that a control transfer targets; the empty set
   * is used to represent unknown control flow.
   *)
    fun labelsOf xfer = let
	  fun labelSet f = (case getValue f
		 of LABELS s => s
		  | TOP => LSet.empty
		  | BOT => LSet.empty	(* because of dead code! *)
		  | v => raise Fail(concat[
			"labelsOf: getValue(", CFG.Var.toString f, ") = ", valueToString v
		      ])
		(* end case *))
	  in
	    case xfer
	     of CFG.StdApply{f, ...} => labelSet f
	      | CFG.StdThrow{k, ...} => labelSet k
	      | CFG.Apply{f, ...} => labelSet f
	      | _ => LSet.addList(LSet.empty, CFGUtil.labelsOfXfer xfer)
	    (* end case *)
	  end

  end
