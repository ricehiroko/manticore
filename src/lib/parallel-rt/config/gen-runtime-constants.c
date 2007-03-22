/* gen-runtime-constants.c
 *
 * COPYRIGHT (c) 2007 The Manticore Project (http://manticore.cs.uchicago.edu)
 * All rights reserved.
 *
 * Generate constant values that the runtime systems shares with the 
 * code generator.
 */

#include <stdlib.h>
#include "manticore-rt.h"
#include <stdio.h>
#include "vproc.h"
#include "value.h"
#include "request-codes.h"
#include "../vproc/scheduler.h"

#define PR_OFFSET(obj, symb, lab)	\
	printf("    val " #symb " : IntInf.int = %d\n", (int)((Addr_t)&(obj.lab) - (Addr_t)&obj))
#define PR_DEFINE(symb, val)			\
	printf("    val " #symb " : IntInf.int = %d\n", val)

int main () {
  VProc_t		vp;
  SchedActStkItem_t	actcons;

  printf ("structure RuntimeConstants : RUNTIME_CONSTS =\n");
  printf ("  struct\n");

  printf ("\n  (* word size and alignment *)\n");
  printf ("    val wordSzB = 0w%d\n", sizeof (Word_t));
  printf ("    val wordAlignB = 0w%d\n", sizeof (Word_t));
  printf ("    val boolSzB = 0w%d\n", sizeof (Word_t));
  printf ("    val extendedAlignB = 0w%d\n", sizeof (double));

  printf ("\n  (* stack size and heap size info *)\n");
  printf ("    val spillAreaSzB = 0w%d\n", FRAME_SZB);
  printf ("    val maxObjectSzB = 0w%d\n", ((sizeof (Word_t)*8)-MIXED_TAG_BITS)*sizeof(Word_t));

  printf ("\n  (* offsets into the VProc_t structure *)\n");
  PR_OFFSET(vp, inManticore, inManticore);
  PR_OFFSET(vp, atomic, atomic);
  PR_OFFSET(vp, sigPending, sigPending);
  PR_OFFSET(vp, allocPtr, allocPtr);
  PR_OFFSET(vp, limitPtr, limitPtr);
  PR_OFFSET(vp, stdArg, stdArg);
  PR_OFFSET(vp, stdPtr, stdEnvPtr);
  PR_OFFSET(vp, stdCont, stdCont);
  PR_OFFSET(vp, stdExnCont, stdExnCont);
  PR_OFFSET(vp, actionStk, actionStk);  

  printf("\n  (* mask to get address of VProc from alloc pointer *)\n");
  printf("    val vpMask : IntInf.int = %0lx\n", ~(VP_HEAP_SZB-1));
  
  printf ("  end (* RuntimeConstants *)\n");

}
