(* demo.sml - parses a small in-memory ISO BMFF (MP4) buffer built as a
   literal Word8Vector: an `ftyp` box followed by a `moov` container box
   with a single `mvhd` child. No fixture file, no I/O. *)

structure M = Mp4

fun w8 n = Word8.fromInt n
fun be32 n =
  [ w8 ((n div 16777216) mod 256), w8 ((n div 65536) mod 256),
    w8 ((n div 256) mod 256), w8 (n mod 256) ]
fun ascii s = List.map (w8 o Char.ord) (String.explode s)
fun boxBytes kind payload = be32 (8 + List.length payload) @ ascii kind @ payload

fun fmtReal r =
  let val r' = if Real.== (r, 0.0) then 0.0 else r
  in Real.fmt (StringCvt.FIX (SOME 3)) r' end

val ftypPayload = ascii "isom" @ be32 512 @ ascii "isom" @ ascii "iso2" @ ascii "mp41"
val ftypBytes   = boxBytes "ftyp" ftypPayload

val mvhdPayload =
  List.tabulate (4, fn _ => w8 0)   (* version(1) + flags(3) *)
  @ List.tabulate (4, fn _ => w8 0) (* creation time *)
  @ List.tabulate (4, fn _ => w8 0) (* modification time *)
  @ be32 1000                       (* timescale *)
  @ be32 5000                       (* duration *)
val mvhdBytes = boxBytes "mvhd" mvhdPayload
val moovBytes = boxBytes "moov" mvhdBytes

val buf = Word8Vector.fromList (ftypBytes @ moovBytes)

val () = print "ISO BMFF box tree:\n"
val boxes = M.parse buf
val () = print (M.toString boxes)

val () = print "\nftyp fields:\n"
val () =
  case M.find "ftyp" boxes of
      NONE => print "  not found\n"
    | SOME box =>
        (print ("  payloadLength = " ^ Int.toString (M.payloadLength box) ^ "\n");
         case M.ftyp buf box of
             NONE => print "  ftyp: NONE\n"
           | SOME { major, minor, compatible } =>
               print ("  major=" ^ major ^ " minor=" ^ Int.toString minor
                      ^ " compatible=[" ^ String.concatWith "," compatible ^ "]\n"))

val () = print "\nmoov/mvhd fields:\n"
val () =
  case M.path ["moov", "mvhd"] boxes of
      NONE => print "  not found\n"
    | SOME box =>
        case M.mvhd buf box of
            NONE => print "  mvhd: NONE\n"
          | SOME { timescale, duration } =>
              print ("  timescale=" ^ Int.toString timescale
                     ^ " duration=" ^ Int.toString duration ^ "\n")

val () = print "\nmovieDuration (seconds):\n"
val () =
  case M.movieDuration buf boxes of
      NONE => print "  NONE\n"
    | SOME d => print ("  " ^ fmtReal d ^ "\n")
