# bpf-learner

<https://qmonnet.github.io/whirl-offload/2020/04/12/llvm-ebpf-asm/>

learning how to write bpf

## 1. bpf basics

read [C code](./my_bpf_program.c)

```sh
Σ cat my_bpf_program.c 
int func() { return 0; }
```

```sh
clang -target bpf -Wall -O2 -c my_bpf_program.c -o my_bpf_objfile.o
```

read the compiled ELF file from BPF

the overview

```sh
Σ hexdump -C my_bpf_objfile.o
00000000  7f 45 4c 46 02 01 01 00  00 00 00 00 00 00 00 00  |.ELF............|
00000010  01 00 f7 00 01 00 00 00  00 00 00 00 00 00 00 00  |................|
00000020  00 00 00 00 00 00 00 00  d8 00 00 00 00 00 00 00  |................|
00000030  00 00 00 00 40 00 00 00  00 00 40 00 05 00 01 00  |....@.....@.....|
00000040  b7 00 00 00 00 00 00 00  95 00 00 00 00 00 00 00  |................|
00000050  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
00000060  00 00 00 00 00 00 00 00  1a 00 00 00 04 00 f1 ff  |................|
00000070  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
00000080  15 00 00 00 12 00 02 00  00 00 00 00 00 00 00 00  |................|
00000090  10 00 00 00 00 00 00 00  00 2e 74 65 78 74 00 2e  |..........text..|
000000a0  6c 6c 76 6d 5f 61 64 64  72 73 69 67 00 66 75 6e  |llvm_addrsig.fun|
000000b0  63 00 6d 79 5f 62 70 66  5f 70 72 6f 67 72 61 6d  |c.my_bpf_program|
000000c0  2e 63 00 2e 73 74 72 74  61 62 00 2e 73 79 6d 74  |.c..strtab..symt|
000000d0  61 62 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |ab..............|
000000e0  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
00000110  00 00 00 00 00 00 00 00  2b 00 00 00 03 00 00 00  |........+.......|
00000120  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
00000130  98 00 00 00 00 00 00 00  3b 00 00 00 00 00 00 00  |........;.......|
00000140  00 00 00 00 00 00 00 00  01 00 00 00 00 00 00 00  |................|
00000150  00 00 00 00 00 00 00 00  01 00 00 00 01 00 00 00  |................|
00000160  06 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
00000170  40 00 00 00 00 00 00 00  10 00 00 00 00 00 00 00  |@...............|
00000180  00 00 00 00 00 00 00 00  08 00 00 00 00 00 00 00  |................|
00000190  00 00 00 00 00 00 00 00  07 00 00 00 03 4c ff 6f  |.............L.o|
000001a0  00 00 00 80 00 00 00 00  00 00 00 00 00 00 00 00  |................|
000001b0  98 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
000001c0  04 00 00 00 00 00 00 00  01 00 00 00 00 00 00 00  |................|
000001d0  00 00 00 00 00 00 00 00  33 00 00 00 02 00 00 00  |........3.......|
000001e0  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
000001f0  50 00 00 00 00 00 00 00  48 00 00 00 00 00 00 00  |P.......H.......|
00000200  01 00 00 00 02 00 00 00  08 00 00 00 00 00 00 00  |................|
00000210  18 00 00 00 00 00 00 00                           |........|
00000218
```

From the `man` page of `elf`:

```txt
The header file <elf.h> defines the format of ELF executable binary files.  Amongst these files are normal executable files, relocatable object files, core files, and shared objects.

       An executable file using the ELF file format consists of an ELF header, followed by a program header table or a section header table, or both.  The ELF header is always at offset zero of the file.  The program header table and the section header table's offset in the file are defined in the ELF header.  The two tables describe the rest of the particularities of the file.

       This header file describes the above mentioned headers as C structures and also includes structures for dynamic sections, relocation sections and symbol tables.
```

So, it looks like in the overview.

```txt
------------------
| ELF header     |
------------------
| program header |
-----------------
| section header |
------------------
```

extract only text content

```sh
Σ readelf -x .text my_bpf_objfile.o 

Hex dump of section '.text':
  0x00000000 b7000000 00000000 95000000 00000000 ................
```

It has two instructions of BPF:

```sh
b7000000 00000000 # r0 = 0
95000000 00000000 # exit and return r0
```

The basic instruction encoding: 64 bits, while the wide instruction encoding takes up 128 bits with a 64-bit basic instruction plus a 64-bit immediate[^bpf-encoding].

The basic instruction encoding is as follows:

```txt
msb                                                                               lsb
+----------------+----------------+----------------+----------------+---------------+
| 32-bits imm    | 16 bits offset | 4 bits src_reg | 4 bits dst_reg | 8 bits opcode |
+----------------+----------------+----------------+----------------+---------------+
```

- imm
  - signed integer immediate value
- offset
  - signed integer offset used with pointer arithmetic
- src_reg
  - the source register number (0-10), except where otherwise specified (64-bit immediate instructions reuse this field for other purposes)
- dst_reg
  - destination register number (0-10)
- opcode
  - operation to perform

Let's refer to the [unofficial eBPF spec](https://github.com/iovisor/bpf-docs/blob/master/eBPF.md) for more details.

opcode `0xb7` is `mov dst, imm` and `0x95` is `exit`(`return r0`). So, the program is:

```c
r0 = 0;
exit();
```

[^bpf-encoding]: https://docs.kernel.org/bpf/instruction-set.html#id4

## 2. BPF program

compile [C program](./bpf.c) into [BPF assembly](./bpf.s)

```sh
Σ clang -target bpf -S -o bpf.s bpf.c # compile C program into BPF assembly
Σ bat bpf.s --plain 
    .text
    .file   "bpf.c"
    .globl  func                            # -- Begin function func
    .p2align    3
    .type   func,@function
func:                                   # @func
# %bb.0:
    r0 = 0
    exit
.Lfunc_end0:
    .size   func, .Lfunc_end0-func
                                        # -- End function
    .addrsig
```

modify

```sh
Σ sed -i '$a \\tr0 = 3' bpf.s # add r0 = 3 at the end of the file
Σ bat --plain bpf.s
    .text
    .file   "bpf.c"
    .globl  func                            # -- Begin function func
    .p2align    3
    .type   func,@function
func:                                   # @func
# %bb.0:
    r0 = 0
    exit
.Lfunc_end0:
    .size   func, .Lfunc_end0-func
                                        # -- End function
    .addrsig
    r0 = 3 
```

assemble this file into an ELF object file containing the bytecode for this program.

```sh
Σ llvm-mc -triple bpf -filetype=obj -o bpf.o bpf.s
Σ readelf -x .text bpf.o 

Hex dump of section '.text':
  0x00000000 b7000000 00000000 95000000 00000000 ................
  0x00000010 b7000000 03000000                   ........
```

this instruction is added compared to the previous sections, which is `r0 = 3`[^bpf-spec].

```sh
b7000000 03000000 # r0 = 3
```

[^bpf-spec]: https://github.com/iovisor/bpf-docs/blob/master/eBPF.md

It is also possible to dump the code in hexadecimal format using `llvm-objdump`:

```sh
Σ llvm-objdump -d bpf.o # use `-d` to dump the code in hexadecimal format

bpf.o:  file format elf64-bpf

Disassembly of section .text:

0000000000000000 <func>:
       0:       b7 00 00 00 00 00 00 00 r0 = 0
       1:       95 00 00 00 00 00 00 00 exit
       2:       b7 00 00 00 03 00 00 00 r0 = 3
```

## 3. BPF program with debug info

we can add debug information when compiling the BPF program. This is done by adding the `-g` flag to the `clang` command.

```sh
Σ clang -target bpf -g -S -o bpf.s bpf.c # added debug info
Σ llvm-mc -triple bpf -filetype=obj -o bpf.o bpf.s # assemble as before
Σ llvm-objdump -S bpf.o # dump the code with debug info, use `-S` flag

bpf.o:  file format elf64-bpf

Disassembly of section .text:

0000000000000000 <func>:
; int func() { return 0; }
       0:       b7 00 00 00 00 00 00 00 r0 = 0
       1:       95 00 00 00 00 00 00 00 exit
```

## 4. inline BPF program

write [`inline_asm.c`](./inline_asm.c) to test inline BPF program.

```c
int func() {
  unsigned long long foobar = 2, r3 = 3, *foobar_addr = &foobar;
  asm volatile("lock *(u64 *)(%0+0) += %1"
               : "=r"(foobar_addr)
               : "r"(r3), "0"(foobar_addr));
  return foobar;
}
```

compile it with `clang` and dump the code with `llvm-objdump`.

```sh
Σ clang -target bpf -Wall -O2 -c inline_asm.c -o inline_asm.o
Σ llvm-objdump -d inline_asm.o

inline_asm.o:   file format elf64-bpf

Disassembly of section .text:

0000000000000000 <func>:
       0:       b7 01 00 00 02 00 00 00 r1 = 2
       1:       7b 1a f8 ff 00 00 00 00 *(u64 *)(r10 - 8) = r1
       2:       b7 01 00 00 03 00 00 00 r1 = 3
       3:       bf a2 00 00 00 00 00 00 r2 = r10
       4:       07 02 00 00 f8 ff ff ff r2 += -8
       5:       db 12 00 00 00 00 00 00 lock *(u64 *)(r2 + 0) += r1
       6:       79 a0 f8 ff 00 00 00 00 r0 = *(u64 *)(r10 - 8)
       7:       95 00 00 00 00 00 00 00 exit
```

## Conclusion

- `clang -target bpf -S -o bpf.s bpf.c`: compile C program into BPF assembly
- `llvm-mc -triple bpf -filetype=obj -o bpf.o bpf.s`: assemble BPF assembly into ELF object file
- `llvm-objdump -d bpf.o`: dump the code in hexadecimal format
- `llvm-objdump -S bpf.o`: dump the code with debug info, which requires `-g` flag when compiling the BPF program
