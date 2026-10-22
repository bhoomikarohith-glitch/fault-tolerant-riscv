# SECDED Encoder Specification

**Project:** Fault-Tolerant RV32I RISC-V Processor  
**Module:** SECDED (39,32) Encoder  
**RTL File:** `rtl/ecc/secded_enc.sv`  
**Specification File:** `docs/specs/secded_enc.md`  
**Status:** Design Specification

## 1. Purpose

The SECDED Encoder adds 7 check bits to every 32-bit word written to memory. With these bits, the matching decoder can **c**orrect any **s**ingle-bit **e**rror and **d**etect any **d**ouble-bit **e**rror (SECDED) caused, for example, by a radiation-induced bit flip.

The module is purely combinational.

## 2. Functional Requirements

The module shall:

1. Accept a 32-bit data word.
2. Produce a 39-bit codeword: 32 data bits, 6 Hamming check bits and 1 overall parity bit.
3. Place bits according to the layout in Section 4.
4. Guarantee that every single-bit error in the codeword produces a unique, nonzero position in the decoder, and every double-bit error is detectable.

The module shall not detect or correct errors. That is the decoder's job.

## 3. Interface Specification

| Signal | Direction | Width | Description |
|---|---|---|---|
| `data` | Input | 32 bits | Data word to protect |
| `codeword` | Output | 39 bits | Data plus 7 check bits |

## 4. Codeword Layout

| Codeword bit | Contents |
|---|---|
| `codeword[0]` | Overall parity: XOR of `codeword[38:1]`, so the whole codeword has even parity |
| `codeword[1]`, `[2]`, `[4]`, `[8]`, `[16]`, `[32]` | Hamming check bits p0 to p5 |
| All other positions 3 to 38 | `data[0]` to `data[31]`, in increasing order |

Check bit p_k, at position 2^k, is the XOR of all data bits whose position number has bit k set. For example, p0 (position 1) covers positions 3, 5, 7, 9 … and p1 (position 2) covers positions 3, 6, 7, 10, 11 ….

## 5. Why It Works

- **Single error:** when the decoder recomputes the six checks over the received codeword, the checks that fail spell out the position number of the flipped bit in binary (the *syndrome*). The overall parity is odd. The decoder flips that bit back.
- **Error in the parity bit itself:** the syndrome is zero but the overall parity is odd; only `codeword[0]` is wrong, and the data is intact.
- **Double error:** the syndrome is nonzero but the overall parity is even again. The decoder knows two bits are wrong but not which, so it flags an uncorrectable error.

**Design decision:** a plain (38,32) Hamming code corrects single errors but would mis-correct a double error into a third wrong bit. The extra overall parity bit makes double errors detectable, at a cost of one bit per word (39 instead of 38).

## 6. Overhead

7 check bits per 32 data bits: 21.9% extra storage. The memories' `WIDTH` parameter becomes 39 when ECC is integrated.

## 7. Integration Requirements

The encoder will sit on the write path of the instruction and data memories, and the decoder on their read path. Integration is a later step; this module is verified standalone first.

## 8. Verification Requirements

The unit testbench `tb/unit/secded_enc_tb.sv` contains a reference decoder and checks, for 236 data words (all-zeros, all-ones, alternating patterns, all 32 walking-one words and 200 random words):

- A clean codeword has zero syndrome, even parity and decodes to the original data.
- All 39 single-bit flips are located exactly and corrected to the original data.
- All 741 double-bit flips are detected as uncorrectable.

Run it with `make ecc-test`.

## 9. Completion Criteria

The module is considered complete when:

- [ ] The codeword layout matches Section 4.
- [ ] Every single-bit error is correctable and every double-bit error detectable.
- [ ] The implementation passes its unit testbench.

## 10. File Locations

RTL:

`rtl/ecc/secded_enc.sv`

Unit testbench:

`tb/unit/secded_enc_tb.sv`

Specification:

`docs/specs/secded_enc.md`
