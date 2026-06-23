structure Tests = struct open Harness structure M = Mp4
fun u32 n = String.implode (List.map Char.chr [(n div 16777216) mod 256, (n div 65536) mod 256, (n div 256) mod 256, n mod 256])
fun bytes s = Word8Vector.fromList (List.map (Word8.fromInt o Char.ord) (String.explode s))
fun kindOf (M.Box b) = #kind b
fun sizeOf (M.Box b) = #size b
fun run () = let
  val () = section "single ftyp box"
  val ftyp = bytes (u32 8 ^ "ftyp")
  val boxes = M.parse ftyp
  val () = checkInt "one box" (1, List.length boxes)
  val () = checkString "kind is ftyp" ("ftyp", kindOf (hd boxes))
  val () = checkInt "size is 8" (8, sizeOf (hd boxes))

  val () = section "multiple top-level boxes with real sizes"
  (* ftyp(size 16, 8 bytes payload) then free(size 8) *)
  val data = bytes (u32 16 ^ "ftyp" ^ "isom\000\000\002\000" ^ u32 8 ^ "free")
  val bs = M.parse data
  val () = checkInt "two boxes" (2, List.length bs)
  val () = checkString "first kind ftyp" ("ftyp", kindOf (List.nth (bs, 0)))
  val () = checkInt "first size 16" (16, sizeOf (List.nth (bs, 0)))
  val () = checkString "second kind free" ("free", kindOf (List.nth (bs, 1)))
  val () = checkInt "second size 8" (8, sizeOf (List.nth (bs, 1)))

  val () = section "truncated / empty input"
  val () = checkInt "empty -> no boxes" (0, List.length (M.parse (bytes "")))
  val () = checkInt "less than 8 bytes -> no boxes" (0, List.length (M.parse (bytes "abc")))
in Harness.run () end end
