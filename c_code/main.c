#include <stdint.h>

#define FIR_BASE       0x80000040UL

#define FIR_CONTROL    (*(volatile uint32_t *)(FIR_BASE + 0x00))
#define FIR_STATUS     (*(volatile uint32_t *)(FIR_BASE + 0x04))
#define FIR_RESULT     (*(volatile uint32_t *)(FIR_BASE + 0x08))

#define FIR_SAMPLE(n)  (*(volatile uint32_t *)(FIR_BASE + 0x10 + ((n) * 4)))
#define FIR_COEFF(n)   (*(volatile uint32_t *)(FIR_BASE + 0x30 + ((n) * 4)))

#define UART_DIV        (*(volatile uint32_t *)0x80000008UL)
#define UART_DATA       (*(volatile uint32_t *)0x8000000CUL)

static void uart_putc(char c)
{
    UART_DATA = (uint32_t)c;
}

static void uart_puts(const char *s)
{
    while (*s) {
        uart_putc(*s++);
    }
}

int main(void)
{
    int i;
    uint32_t result;

    UART_DIV = 173;

    uart_puts("\r\n");
    uart_puts("RISC-V FIR DSP ACCELERATOR\r\n");
    uart_puts("Loading data...\r\n");

    for (i = 0; i < 8; i++) {
        FIR_SAMPLE(i) = (uint32_t)(i + 1);
        FIR_COEFF(i) = 1;
    }

    uart_puts("Starting accelerator...\r\n");

    FIR_CONTROL = 1;

    while ((FIR_STATUS & 0x2) == 0) {
        ;
    }

    result = FIR_RESULT;

    uart_puts("Accelerator completed.\r\n");

    if (result == 36) {
        uart_puts("FIR RESULT = 36\r\n");
        uart_puts("STATUS = PASS\r\n");
    } else {
        uart_puts("STATUS = FAIL\r\n");
    }

    while (1) {
        ;
    }

    return 0;
}