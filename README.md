# sml-mp4

[![CI](https://github.com/sjqtentacles/sml-mp4/actions/workflows/ci.yml/badge.svg)](https://github.com/sjqtentacles/sml-mp4/actions/workflows/ci.yml)

ISO Base Media File Format (MP4 / `.mov`) **box** scanning for Standard ML.
Reads the top-level box list — each box's 4-character type and 32-bit size —
from a byte vector.

## API

```sml
datatype box = Box of { kind : string, size : int, children : box list }

Mp4.parse bytes   (* -> box list (top level) *)
```

```sml
val boxes = Mp4.parse data
List.map (fn Mp4.Box b => #kind b) boxes   (* e.g. ["ftyp", "moov", "mdat"] *)
```

## Scope and limitations

- **Top-level boxes only — this is a flat scanner, not a tree parser.** The
  `children` field is always `[]`; container boxes (`moov`, `trak`, …) are
  reported as single boxes and are not recursed into.
- Reads 32-bit (`size`) box sizes. The 64-bit large-size form (`size == 1` with
  an 8-byte extended size) and `size == 0` (box-to-end-of-file) are not
  specially handled.
- Box payloads are not interpreted — no `ftyp` brands, sample tables, codec
  configuration, etc.

## Installing with smlpkg

```sh
smlpkg add github.com/sjqtentacles/sml-mp4
smlpkg sync
```

Reference from your `.mlb`:

```
lib/github.com/sjqtentacles/sml-mp4/mp4.mlb
```

## Building and testing

```sh
make test        # MLton
make test-poly   # Poly/ML
make all-tests   # both
make clean
```

## Project layout

```
sml.pkg
Makefile
lib/github.com/sjqtentacles/sml-mp4/
  mp4.sig
  mp4.sml      top-level box (size + 4cc) scanner
  mp4.mlb
test/
  test.sml     single box, multiple boxes with sizes, truncated input
```

## License

MIT. See [LICENSE](LICENSE).
