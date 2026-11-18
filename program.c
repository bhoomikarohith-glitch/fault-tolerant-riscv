/* Disable hosted sanitizer instrumentation for this bare-metal example. */
#if defined(__clang__)
#pragma clang attribute push (__attribute__((no_sanitize("undefined"))), apply_to=function)
#endif

/* Three-by-three matrix multiplication, sorting, recursion, and checksum. */
static const unsigned int A[9] = {3, 1, 2, 4, 0, 2, 1, 5, 3};
static const unsigned int B[9] = {2, 1, 0, 3, 4, 2, 1, 2, 5};
volatile unsigned int matrix[9];
volatile unsigned int sorted[9];
volatile unsigned int checksum;
volatile unsigned int factorial_result;

static void multiply_matrices(const unsigned int *a,
                              const unsigned int *b,
                              volatile unsigned int *out)
{
    for (unsigned int row = 0; row < 3; row++) {
        for (unsigned int col = 0; col < 3; col++) {
            unsigned int total = 0;
            for (unsigned int k = 0; k < 3; k++) {
                total += a[row * 3 + k] * b[k * 3 + col];
            }
            out[row * 3 + col] = total;
        }
    }
}

static void bubble_sort(volatile unsigned int *values, unsigned int count)
{
    for (unsigned int pass = 0; pass + 1 < count; pass++) {
        for (unsigned int j = 0; j + 1 < count - pass; j++) {
            if (values[j] > values[j + 1]) {
                unsigned int temp = values[j];
                values[j] = values[j + 1];
                values[j + 1] = temp;
            }
        }
    }
}

__attribute__((noinline))
static unsigned int factorial(unsigned int n)
{
    if (n <= 1) {
        return 1;
    }
    return n * factorial(n - 1);
}

int main(void)
{
    volatile unsigned int *source = matrix;
    volatile unsigned int *values = sorted;
    multiply_matrices(A, B, source);

    for (unsigned int i = 0; i < 9; i++) {
        values[i] = source[i];
    }
    bubble_sort(values, 9);

    checksum = 0;
    for (unsigned int i = 0; i < 9; i++) {
        checksum += (i + 1) * values[i];
    }

    factorial_result = factorial(6);
    return (int)(multiply_matrices);
}

#if defined(__clang__)
#pragma clang attribute pop
#endif
