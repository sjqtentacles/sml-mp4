signature MP4 =
sig
  datatype box = Box of { kind : string, size : int, children : box list }

  (* Top-level (recursive) parse: known container boxes are descended into and
     their children populated; leaf boxes have `children = []`. *)
  val parse : Word8Vector.vector -> box list

  (* True for the ISO BMFF container boxes whose payload is itself a sequence of
     boxes (moov, trak, mdia, minf, stbl, udta, dinf, edts, mvex, moof, traf). *)
  val isContainer : string -> bool

  (* Recursively collect all boxes of a given kind (depth-first, pre-order). *)
  val findAll : string -> box list -> box list
end
