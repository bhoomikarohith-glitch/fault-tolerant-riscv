# bubble_sort.S
# Stores eight numbers, sorts them in ascending order with bubble sort,
# then computes an order-sensitive checksum and writes it to the result
# address. Runs unchanged in Ripes.
#
#   input : 29, 3, 17, 8, 42, 1, 15, 6
#   sorted: 1, 3, 6, 8, 15, 17, 29, 42   (inspect memory at 0x800 in Ripes)
#   checksum = sum of (a[i] << i) = 8111 (0x1FAF), in a0 and at 0xFFC
#   A wrong order gives a different checksum.

        .text
        .globl _start
_start:
        li    s0, 0x800           # array base
        li    s1, 8               # number of elements

        # --- build the array
        li    t0, 29
        sw    t0, 0(s0)
        li    t0, 3
        sw    t0, 4(s0)
        li    t0, 17
        sw    t0, 8(s0)
        li    t0, 8
        sw    t0, 12(s0)
        li    t0, 42
        sw    t0, 16(s0)
        li    t0, 1
        sw    t0, 20(s0)
        li    t0, 15
        sw    t0, 24(s0)
        li    t0, 6
        sw    t0, 28(s0)

        # --- bubble sort: repeat passes until no swaps happen
outer:
        li    t6, 0               # swapped = 0
        mv    t2, s0              # pointer to a[j]
        addi  t1, s1, -1          # comparisons per pass
inner:
        lw    t3, 0(t2)           # a[j]
        lw    t4, 4(t2)           # a[j+1]
        bge   t4, t3, no_swap     # already in order (signed compare)
        sw    t4, 0(t2)
        sw    t3, 4(t2)
        li    t6, 1               # swapped = 1
no_swap:
        addi  t2, t2, 4
        addi  t1, t1, -1
        bnez  t1, inner
        bnez  t6, outer

        # --- checksum = sum of a[i] << i
        li    a0, 0
        li    t1, 0               # i
        mv    t2, s0
sum_loop:
        lw    t3, 0(t2)
        sll   t3, t3, t1
        add   a0, a0, t3
        addi  t2, t2, 4
        addi  t1, t1, 1
        blt   t1, s1, sum_loop

        # --- report
        li    t0, 0xFFC
        sw    a0, 0(t0)
done:   j     done