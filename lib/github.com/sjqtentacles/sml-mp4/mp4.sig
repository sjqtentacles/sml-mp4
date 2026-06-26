signature MP4 =
sig
  (* An ISO BMFF box.
       kind       : the 4-character box type
       size       : the box size in bytes (header + payload)
       offset     : byte offset of the box header within the file
       dataOffset : byte offset of the box payload (after size+type, and after
                    the 64-bit largesize when present)
       children   : parsed sub-boxes for container boxes ([] for leaves) *)
  datatype box = Box of
    { kind : string
    , size : int
    , offset : int
    , dataOffset : int
    , children : box list }

  (* field accessors *)
  val kind       : box -> string
  val size       : box -> int
  val offset     : box -> int
  val dataOffset : box -> int
  val children   : box -> box list
  (* byte length of the payload (size - header). *)
  val payloadLength : box -> int

  (* Recursive parse: known container boxes are descended into. *)
  val parse : Word8Vector.vector -> box list

  val isContainer : string -> bool

  (* Recursively collect all boxes of a given kind (depth-first, pre-order). *)
  val findAll : string -> box list -> box list
  (* The first box of a given kind, if any. *)
  val find    : string -> box list -> box option
  (* Follow a path of kinds (e.g. ["moov","trak","mdia"]), returning the box at
     the end of the first matching chain. *)
  val path    : string list -> box list -> box option

  (* The raw payload bytes of a box, sliced from the original vector. *)
  val payload : Word8Vector.vector -> box -> Word8Vector.vector

  (* ---- typed box parsing ---- *)

  (* ftyp: (majorBrand, minorVersion, compatibleBrands). *)
  val ftyp : Word8Vector.vector -> box -> { major : string, minor : int, compatible : string list } option

  (* FullBox header: (version, flags) read from the first 4 payload bytes. *)
  val fullBox : Word8Vector.vector -> box -> { version : int, flags : int }

  (* mvhd: movie header timescale + duration (handles version 0 and 1). *)
  val mvhd : Word8Vector.vector -> box -> { timescale : int, duration : int } option
  (* tkhd: track header timescale is implicit; returns trackId + duration. *)
  val tkhd : Word8Vector.vector -> box -> { trackId : int, duration : int } option
  (* mdhd: media header timescale + duration. *)
  val mdhd : Word8Vector.vector -> box -> { timescale : int, duration : int } option

  (* Movie duration in seconds from the moov/mvhd (duration / timescale). *)
  val movieDuration : Word8Vector.vector -> box list -> real option

  (* A short human-readable dump of the box tree. *)
  val toString : box list -> string
end
