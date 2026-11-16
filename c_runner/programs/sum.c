/* The initialized array tests .data loading. result tests zeroed .bss. */
volatile int numbers[10] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
volatile int result;

__attribute__((noinline))
static int sum_array(volatile const int *values, int count)
{
    int total = 0;
    for (int i = 0; i < count; i++) {
        total += values[i];
    }
    return total;
}

int main(void)
{
    if (result != 0) {
        return -1;
    }
    result = sum_array(numbers, 10);
    return result; /* Expected result is 55. */
}
