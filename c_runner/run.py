#!/usr/bin/env python3
"""Build a freestanding RV32I C program and run it on the repository RTL."""
import argparse
import importlib.util
from pathlib import Path
import shutil
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build" / "c_runner"


def run(command):
    print("+ " + " ".join(map(str, command)), flush=True)
    subprocess.run(list(map(str, command)), cwd=ROOT, check=True)


def memory_image(elf_path, output_path):
    """Extract ELF32 little-endian load segments into a full 4 KB hex image."""
    data = elf_path.read_bytes()
    if data[:7] != b"\x7fELF\x01\x01\x01":
        raise ValueError("Expected ELF32 little-endian input")
    header = struct.unpack_from("<16sHHIIIIIHHHHHH", data)
    if header[2] != 243 or header[4] != 0:
        raise ValueError("Expected RISC-V ELF with entry address zero")
    # Reject ELF flags for compressed instructions or a floating-point ABI.
    if header[7] & 0x7:
        raise ValueError("ELF requires compressed instructions or a floating-point ABI")
    phoff, phentsize, phnum = header[5], header[9], header[10]
    image = bytearray(4096)
    occupied = bytearray(4096)
    loaded = 0
    for index in range(phnum):
        fields = struct.unpack_from("<IIIIIIII", data, phoff + index * phentsize)
        kind, offset, address, _, file_size, memory_size, _, _ = fields
        if kind != 1 or memory_size == 0:
            continue
        if file_size > memory_size or offset + file_size > len(data):
            raise ValueError("Invalid ELF segment size")
        if address + memory_size > len(image):
            raise ValueError("ELF load segment exceeds 4 KB RTL memory")
        if any(occupied[address:address + memory_size]):
            raise ValueError("Overlapping ELF load segments")
        occupied[address:address + memory_size] = b"\x01" * memory_size
        image[address:address + file_size] = data[offset:offset + file_size]
        loaded += file_size
    if loaded == 0:
        raise ValueError("ELF has no loadable contents")
    output_path.write_text("".join(
        f"{int.from_bytes(image[i:i + 4], 'little'):08x}\n"
        for i in range(0, len(image), 4)
    ))
    print(f"Wrote 1024 memory words from {loaded} loadable ELF bytes", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--program", choices=["sum", "factorial"], default="sum")
    parser.add_argument("--source", type=Path, help="Use your own C file")
    parser.add_argument("--expected", type=int, help="Required for --source")
    parser.add_argument("--vcd", action="store_true")
    parser.add_argument("--max-cycles", type=int, default=100000)
    args = parser.parse_args()
    if args.source and args.expected is None:
        parser.error("--source requires --expected")
    source = args.source.resolve() if args.source else ROOT / "c_runner" / "programs" / (args.program + ".c")
    if not source.is_file():
        parser.error(f"C file does not exist: {source}")
    expected = args.expected if args.expected is not None else {"sum": 55, "factorial": 720}[args.program]
    if not -(2**31) <= expected < 2**31:
        parser.error("--expected must fit in a signed 32-bit int")
    if args.max_cycles < 1:
        parser.error("--max-cycles must be positive")
    BUILD.mkdir(parents=True, exist_ok=True)

    gcc = shutil.which("riscv64-unknown-elf-gcc")
    if importlib.util.find_spec("ziglang"):
        compiler = [sys.executable, "-m", "ziglang", "cc", "-target",
                    "riscv32-freestanding", "-mcpu=generic_rv32"]
    elif gcc:
        compiler = [gcc, "-march=rv32i"]
    else:
        parser.error('Install the C compiler with: python -m pip install "ziglang==0.13.0"')

    elf = BUILD / "program.elf"
    run(compiler + [
        "-mabi=ilp32", "-O0", "-g", "-ffreestanding",
        "-fno-builtin", "-fno-stack-protector", "-fno-pic", "-fno-pie",
        "-fno-unwind-tables", "-fno-asynchronous-unwind-tables",
        "-ffunction-sections", "-fdata-sections", "-msmall-data-limit=0",
        "-mno-relax", "-nostdlib",
        "-Wl,--gc-sections", "-Wl,-T,c_runner/link.ld",
        "-o", elf,
        "c_runner/start.S", source, "c_runner/runtime.c",
    ])
    memory_image(elf, BUILD / "program.mem")

    if importlib.util.find_spec("verilator"):
        simulator = [sys.executable, "-m", "verilator"]
    elif shutil.which("verilator"):
        simulator = [shutil.which("verilator")]
    else:
        parser.error("Install Verilator with: python -m pip install verilator")
    rtl = [ROOT / "rtl/common/rv_pkg.sv", ROOT / "rtl/common/adder.sv", ROOT / "rtl/common/mux2.sv"]
    for folder in ["core", "memory", "multiplier"]:
        rtl.extend(sorted((ROOT / "rtl" / folder).glob("*.sv")))
    rtl.append(ROOT / "rtl/cpu_top.sv")
    missing = [str(path) for path in rtl if not path.is_file()]
    if missing:
        parser.error("Place c_runner beside your rtl folder. Missing files: " + ", ".join(missing))
    run(simulator + [
        "--binary", "--timing", "--assert", "--trace", "-Wno-fatal",
        "--top-module", "tb_c_program", "-j", "4",
        "--Mdir", BUILD / "obj_dir",
    ] + rtl + [ROOT / "c_runner/tb_c_program.sv"])
    run([BUILD / "obj_dir/Vtb_c_program", f"+EXPECTED={expected}",
         f"+MAX_CYCLES={args.max_cycles}"] + (["+vcd"] if args.vcd else []))


if __name__ == "__main__":
    try:
        main()
    except (subprocess.CalledProcessError, ValueError) as error:
        print(f"C simulation failed: {error}", file=sys.stderr)
        sys.exit(1)
