structure PrimList =
  struct

    structure L = List
    structure PT = PrimTypes

  (* list utilities for inline BOM *)
    _primcode (

      typedef list = L.list;

      define @app (f : fun(any / PT.exh -> ), ls : L.list / exh : PT.exh) : () =
	fun lp (f : fun(any / PT.exh -> ), xs : L.list / exh : PT.exh) : () =
	    case xs
	     of L.NIL => return()
	      | L.CONS(x : any, xs : list) =>
		do apply f(x / exh)
		apply lp(f, xs / exh)
	    end
	apply lp(f, ls / exh)
      ;

      define @rev (xs : list / exh : PT.exh) : L.list =
	fun rev (xs : L.list, ys : L.list / exh : PT.exh) : L.list =
	    case xs
	     of L.NIL => return(ys)
	      | L.CONS(x : any, xs : L.list) => apply rev(xs, L.CONS(x, ys) / exh)
	    end
	apply rev(xs, L.NIL / exh)
      ;

      define @map (f : fun(any / PT.exh -> any), ls : L.list / exh : PT.exh) : L.list =
	fun lp (f : fun(any / PT.exh -> any), xs : L.list, ys : L.list / exh : PT.exh) : L.list =
	    case xs
	     of L.NIL => 
		let ys : L.list = @rev(ys / exh)
                return(ys)
	      | L.CONS(x : any, xs : list) =>
		let x : any = apply f(x / exh)
		apply lp(f, xs, L.CONS(x, xs) / exh)
	    end
	apply lp(f, ls, L.NIL / exh)
      ;

      define @append (l1 : L.list, l2 : L.list / exh : PT.exh) : L.list =
	  fun append (l1 : L.list / exh : PT.exh) : L.list =
		case l1
		 of L.CONS(hd:any, tl:L.list) =>
		      let l : L.list = apply append (tl / exh)
			return (L.CONS(hd, l))
		  | L.NIL => return (l2)
		end
	    apply append (l1 / exh)
      ;


      define @nth (l : L.list, n : int / exh : PT.exh) : any =
(* FIXME: raise an exception *)
	cont error () =
	  return(enum(0):any)

	fun lp (l : L.list, n : int / exh : PT.exh) : any =
	    case l
	     of L.NIL => throw error()
	      | L.CONS(x : any, l : L.list) => 
		if I32Eq(n, 0)
		   then return(x)
		else apply lp(l, I32Sub(n, 1) / exh)
            end
	apply lp(l, n / exh)
      ;

    )


  end