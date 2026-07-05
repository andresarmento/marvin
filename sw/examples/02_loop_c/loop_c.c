/*************************************************************************************************
 * MaRVin - RISC-V SoC
 * Example: loop_c
 * Simple loop written in C - increments a global counter forever.
 * counter starts non-zero, so it lives in .data and exercises crt0's rom->ram copy at boot.
 *************************************************************************************************/
volatile int counter = 1;

int main(void)
{
    while (1) {
        counter++;
    }

    return 0;
}
