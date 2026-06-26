structure Tests = struct open Harness structure M = Mp4
fun u32 n = String.implode (List.map Char.chr [(n div 16777216) mod 256, (n div 65536) mod 256, (n div 256) mod 256, n mod 256])
fun u64hi0 lo = u32 0 ^ u32 lo
fun bytes s = Word8Vector.fromList (List.map (Word8.fromInt o Char.ord) (String.explode s))
fun kindOf b = M.kind b
fun sizeOf b = M.size b
fun kidsOf b = M.children b

fun run () = let
  (* ---- structural parsing (kept) ---- *)
  val () = section "single ftyp box"
  val ftyp = bytes (u32 8 ^ "ftyp")
  val boxes = M.parse ftyp
  val () = checkInt "one box" (1, List.length boxes)
  val () = checkString "kind is ftyp" ("ftyp", kindOf (hd boxes))
  val () = checkInt "size is 8" (8, sizeOf (hd boxes))
  val () = checkInt "offset 0" (0, M.offset (hd boxes))
  val () = checkInt "dataOffset 8" (8, M.dataOffset (hd boxes))

  val () = section "multiple top-level boxes"
  val data = bytes (u32 16 ^ "ftyp" ^ "isom\000\000\002\000" ^ u32 8 ^ "free")
  val bs = M.parse data
  val () = checkInt "two boxes" (2, List.length bs)
  val () = checkString "second kind free" ("free", kindOf (List.nth (bs, 1)))
  val () = checkInt "free offset 16" (16, M.offset (List.nth (bs, 1)))

  val () = section "truncated / empty input"
  val () = checkInt "empty -> no boxes" (0, List.length (M.parse (bytes "")))
  val () = checkInt "less than 8 bytes -> no boxes" (0, List.length (M.parse (bytes "abc")))

  val () = section "isContainer"
  val () = checkBool "moov is container" (true, M.isContainer "moov")
  val () = checkBool "ftyp is not container" (false, M.isContainer "ftyp")

  val () = section "recursive + nested + largesize"
  val moov = bytes (u32 16 ^ "moov" ^ u32 8 ^ "mvhd")
  val mb = M.parse moov
  val () = checkInt "moov has one child" (1, List.length (kidsOf (hd mb)))
  val () = checkString "child is mvhd" ("mvhd", kindOf (hd (kidsOf (hd mb))))
  val mdia = u32 8 ^ "mdia"
  val trak = u32 (8 + 8) ^ "trak" ^ mdia
  val moov2 = u32 (8 + String.size trak) ^ "moov" ^ trak
  val nb = M.parse (bytes moov2)
  val () = checkString "nested mdia"
             ("mdia", kindOf (hd (kidsOf (hd (kidsOf (hd nb))))))
  val big = bytes (u32 1 ^ "free" ^ u64hi0 16)
  val () = checkInt "64-bit size 16" (16, sizeOf (hd (M.parse big)))

  (* ---- find / path ---- *)
  val () = section "find / path"
  val tree = M.parse (bytes moov2)
  val () = checkInt "findAll trak" (1, List.length (M.findAll "trak" tree))
  val () = checkBool "find moov" (true, Option.isSome (M.find "moov" tree))
  val () = checkBool "find absent" (false, Option.isSome (M.find "stco" tree))
  val () = checkBool "path moov/trak/mdia"
             (true, case M.path ["moov","trak","mdia"] tree of
                        SOME b => M.kind b = "mdia" | NONE => false)
  val () = checkBool "path miss" (false, Option.isSome (M.path ["moov","stbl"] tree))

  (* ---- ftyp brands ---- *)
  val () = section "ftyp brands"
  val ftypData =
    bytes (u32 (8 + 4 + 4 + 8) ^ "ftyp" ^ "isom" ^ u32 512 ^ "isom" ^ "avc1")
  val ft = M.ftyp ftypData (hd (M.parse ftypData))
  val () = checkBool "ftyp parsed" (true, Option.isSome ft)
  val ftv = valOf ft
  val () = checkString "major brand" ("isom", #major ftv)
  val () = checkInt "minor version" (512, #minor ftv)
  val () = checkStringList "compatible brands" (["isom","avc1"], #compatible ftv)

  (* ---- FullBox version/flags ---- *)
  val () = section "FullBox version/flags"
  (* a generic full box: version=1, flags=0x000007 *)
  val fbData = bytes (u32 12 ^ "hdlr" ^ "\001\000\000\007")
  val fb = M.fullBox fbData (hd (M.parse fbData))
  val () = checkInt "version 1" (1, #version fb)
  val () = checkInt "flags 7" (7, #flags fb)

  (* ---- mvhd timescale + duration (version 0) ---- *)
  val () = section "mvhd timescale + duration"
  (* payload: fullbox(4) creation(4) modification(4) timescale(4) duration(4) ... *)
  val mvhdPayload =
    "\000\000\000\000"          (* version+flags *)
    ^ u32 0 ^ u32 0             (* creation, modification *)
    ^ u32 1000                  (* timescale *)
    ^ u32 5000                  (* duration *)
    ^ u32 0                     (* rate (partial trailing, fine) *)
  val mvhdBox = u32 (8 + String.size mvhdPayload) ^ "mvhd" ^ mvhdPayload
  val mvhdData = bytes mvhdBox
  val mv = M.mvhd mvhdData (hd (M.parse mvhdData))
  val () = checkBool "mvhd parsed" (true, Option.isSome mv)
  val () = checkInt "timescale 1000" (1000, #timescale (valOf mv))
  val () = checkInt "duration 5000" (5000, #duration (valOf mv))

  (* ---- movieDuration via moov/mvhd ---- *)
  val () = section "movieDuration"
  val moovWithMvhd =
    let val inner = u32 (8 + String.size mvhdPayload) ^ "mvhd" ^ mvhdPayload
    in u32 (8 + String.size inner) ^ "moov" ^ inner end
  val durData = bytes moovWithMvhd
  val dur = M.movieDuration durData (M.parse durData)
  val () = checkBool "duration parsed" (true, Option.isSome dur)
  val () = checkRealTol 1E~6 "5000/1000 = 5.0s" (5.0, valOf dur)

  (* ---- payload byte range ---- *)
  val () = section "payload slice"
  val pdata = bytes (u32 12 ^ "data" ^ "ABCD")
  val pb = hd (M.parse pdata)
  val pl = M.payload pdata pb
  val () = checkInt "payload length 4" (4, Word8Vector.length pl)
  val () = checkInt "payloadLength accessor 4" (4, M.payloadLength pb)
  val () = checkInt "payload[0] = 'A'" (Char.ord #"A", Word8.toInt (Word8Vector.sub (pl, 0)))

  (* ---- toString smoke ---- *)
  val () = section "toString"
  val s = M.toString tree
  val () = checkBool "mentions moov" (true, String.isSubstring "moov" s)
  val () = checkBool "mentions mdia" (true, String.isSubstring "mdia" s)

in Harness.run () end end
