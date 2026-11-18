/* Run on the RV32 RTL with c_runner/tb_c_program.sv from this bundle. */
#if defined(__clang__)
#pragma clang attribute push (__attribute__((no_sanitize("undefined"))), apply_to=function)
#endif

static const unsigned int A[3][3] = {
    {3, 1, 2},
    {4, 0, 2},
    {1, 5, 3}
};

static const unsigned int B[3][3] = {
    {2, 1, 0},
    {3, 4, 2},
    {1, 2, 5}
};

static const unsigned int expected[3][3] = {
    {11, 11, 12},
    {10,  8, 10},
    {20, 27, 25}
};

volatile unsigned int matrix[3][3];

int main(void)
{
    /* Reserved word observed by the simulation testbench for output. */
    volatile unsigned int *output = (volatile unsigned int *)0xFF8u;
    unsigned int errors = 0;

    for (unsigned int row = 0; row < 3; row++) {
        for (unsigned int col = 0; col < 3; col++) {
            unsigned int total = 0;
            for (unsigned int k = 0; k < 3; k++) {
                total += A[row][k] * B[k][col];
            }
            matrix[row][col] = total;
        }
    }

    for (unsigned int row = 0; row < 3; row++) {
        for (unsigned int col = 0; col < 3; col++) {
            unsigned int value = matrix[row][col];
            *output = value;
            if (value != expected[row][col]) {
                errors++;
            }
        }
    }

    /* Zero means all nine matrix elements matched their expected values. */
    return (int)errors;
}

#if defined(__clang__)
#pragma clang attribute pop
#endif
