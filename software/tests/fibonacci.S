# fibonacci.S
# Calls a function that computes fib(20) iteratively, then writes the
# answer to the result address. Exercises jal (call) and jalr (return).
# Runs unchanged in Ripes.
#
#   fib(0) = 0, fib(1) = 1, fib(n) = fib(n-1) + fib(n-2)
#   expected result: fib(20) = 6765 (0x1A6D), in a0 and at address 0xFFC

        .text
        .globl _start
_start:
        li    a0, 20              # argument n
        jal   ra, fib             # call; return address saved in ra
        li    t0, 0xFFC
        sw    a0, 0(t0)
done:   j     done

# fib(a0) -> a0. Uses t0-t2 only, so no stack is needed.
fib:
        li    t0, 0               # fib(i)
        li    t1, 1               # fib(i + 1)
        beqz  a0, fib_end
fib_loop:
        add   t2, t0, t1          # next term
        mv    t0, t1
        mv    t1, t2
        addi  a0, a0, -1
        bnez  a0, fib_loop
fib_end:
        mv    a0, t0
        ret                       # jalr x0, 0(ra)