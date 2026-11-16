/* RV32I software multiplication helper. Arithmetic wraps modulo 2^32.
 * The compiler calls this for 32-bit C multiplication on RV32I.
 */
unsigned int __mulsi3(unsigned int a, unsigned int b)
{
    unsigned int product = 0;
    while (b != 0) {
        if ((b & 1u) != 0) {
            product += a;
        }
        a <<= 1;
        b >>= 1;
    }
    return product;
}
