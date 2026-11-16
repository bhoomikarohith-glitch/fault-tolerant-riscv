/* Recursion exercises function calls, stack frames, and return addresses. */
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
    return (int)factorial(6); /* Expected result is 720. */
}
