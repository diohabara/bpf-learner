clean:

task1: my_bpf_program.c
	clang -target bpf -Wall -O2 -c my_bpf_program.c -o my_bpf_objfile.o

clean:
	rm -f my_bpf_objfile.o

.PHONY: clean
