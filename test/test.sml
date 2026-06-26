structure Tests = struct open Harness structure M = Mp4
fun u32 n = String.implode (List.map Char.chr [(n div 16777216) mod 256, (n div 65536) mod 256, (n div 256) mod 256, n mod 256])
fun u64hi0 lo = u32 0 ^ u32 lo  (* 64-bit big-endian for values that fit in 32 bits *)
fun bytes s = Word8Vector.fromList (List.map (Word8.fromInt o Char.ord) (String.explode s))
fun kindOf (M.Box b) = #kind b
fun sizeOf (M.Box b) = #size b
fun kidsOf (M.Box b) = #children b
fun run () = let
  val () = section "single ftyp box"
  val ftyp = bytes (u32 8 ^ "ftyp")
  val boxes = M.parse ftyp
  val () = checkInt "one box" (1, List.length boxes)
  val () = checkString "kind is ftyp" ("ftyp", kindOf (hd boxes))
  val () = checkInt "size is 8" (8, sizeOf (hd boxes))

  val () = section "multiple top-level boxes with real sizes"
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

  val () = section "isContainer"
  val () = checkBool "moov is container" (true, M.isContainer "moov")
  val () = checkBool "trak is container" (true, M.isContainer "trak")
  val () = checkBool "stbl is container" (true, M.isContainer "stbl")
  val () = checkBool "ftyp is not container" (false, M.isContainer "ftyp")
  val () = checkBool "mvhd is not container" (false, M.isContainer "mvhd")

  val () = section "recursive container parsing"
  (* moov (size 16) -> mvhd (size 8) leaf *)
  val moov = bytes (u32 16 ^ "moov" ^ u32 8 ^ "mvhd")
  val mb = M.parse moov
  val () = checkInt "one top box" (1, List.length mb)
  val () = checkString "top is moov" ("moov", kindOf (hd mb))
  val () = checkInt "moov has one child" (1, List.length (kidsOf (hd mb)))
  val () = checkString "child is mvhd" ("mvhd", kindOf (hd (kidsOf (hd mb))))
  val () = checkInt "leaf mvhd no children" (0, List.length (kidsOf (hd (kidsOf (hd mb)))))

  val () = section "deeply nested containers"
  (* moov -> trak -> mdia (leaf for this test) *)
  val mdia = u32 8 ^ "mdia"
  val trak = u32 (8 + 8) ^ "trak" ^ mdia
  val moov2 = u32 (8 + String.size trak) ^ "moov" ^ trak
  val nb = M.parse (bytes moov2)
  val trakBox = hd (kidsOf (hd nb))
  val () = checkString "nested trak" ("trak", kindOf trakBox)
  val () = checkString "nested mdia" ("mdia", kindOf (hd (kidsOf trakBox)))

  val () = section "64-bit largesize (size field = 1)"
  (* free box: size32 = 1 signals 64-bit size in bytes 8..15; largesize = 16 *)
  val big = bytes (u32 1 ^ "free" ^ u64hi0 16)
  val bigBoxes = M.parse big
  val () = checkInt "one large box" (1, List.length bigBoxes)
  val () = checkString "kind free" ("free", kindOf (hd bigBoxes))
  val () = checkInt "decoded 64-bit size 16" (16, sizeOf (hd bigBoxes))

  val () = section "findAll"
  val tree = M.parse (bytes moov2)
  val () = checkInt "findAll trak -> 1" (1, List.length (M.findAll "trak" tree))
  val () = checkInt "findAll mdia -> 1" (1, List.length (M.findAll "mdia" tree))
  val () = checkInt "findAll absent -> 0" (0, List.length (M.findAll "stco" tree))
  val () = checkInt "findAll moov -> 1" (1, List.length (M.findAll "moov" tree))
in Harness.run () end end

