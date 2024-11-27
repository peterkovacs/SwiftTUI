#include "Unicode.h"

typedef struct {
    uint8_t mask;    /* char data will be bitwise AND with this */
    uint8_t lead;    /* start bytes of current char in utf-8 encoded character */
    uint32_t beg; /* beginning of codepoint range */
    uint32_t end; /* end of codepoint range */
    int bits_stored; /* the number of bits from the codepoint that fits in char */
} utf_t;

utf_t * utf[] = {
    /*             mask        lead        beg      end       bits */
    [0] = &(utf_t){0b00111111, 0b10000000, 0,       0,        6    },
    [1] = &(utf_t){0b01111111, 0b00000000, 0000,    0177,     7    },
    [2] = &(utf_t){0b00011111, 0b11000000, 0200,    03777,    5    },
    [3] = &(utf_t){0b00001111, 0b11100000, 04000,   0177777,  4    },
    [4] = &(utf_t){0b00000111, 0b11110000, 0200000, 04177777, 3    },
          &(utf_t){0},
};

int codepoint_len(const uint32_t cp)
{
    int len = 0;
    for(utf_t **u = utf; *u; ++u) {
        if((cp >= (*u)->beg) && (cp <= (*u)->end)) {
            break;
        }
        ++len;
    }
    if(len > 4) /* Out of bounds */
        return -1;

    return len;
}

int utf8_len(const uint8_t ch)
{
    int len = 0;
    for(utf_t **u = utf; *u; ++u) {
        if((ch & ~(*u)->mask) == (*u)->lead) {
            break;
        }
        ++len;
    }
    if(len > 4) { /* Malformed leading byte */
        return -1;
    }
    return len;
}

uint32_t to_codepoint(const uint8_t chr[4])
{
    int bytes = utf8_len(*chr);
    int shift = utf[0]->bits_stored * (bytes - 1);
    uint32_t codep = (*chr++ & utf[bytes]->mask) << shift;

    for(int i = 1; i < bytes; ++i, ++chr) {
        shift -= utf[0]->bits_stored;
        codep |= ((char)*chr & utf[0]->mask) << shift;
    }

    return codep;
}

/*
int main(void)
{
    const uint32_t *in, input[] = {0x0041, 0x00f6, 0x0416, 0x20ac, 0x1d11e, 0x0};

    printf("Character  Unicode  UTF-8 encoding (hex)\n");
    printf("----------------------------------------\n");

    char *utf8;
    uint32_t codepoint;
    for(in = input; *in; ++in) {
        utf8 = to_utf8(*in);
        codepoint = to_cp(utf8);
        printf("%s          U+%-7.4x", utf8, codepoint);

        for(int i = 0; utf8[i] && i < 4; ++i) {
            printf("%hhx ", utf8[i]);
        }
        printf("\n");
    }
    return 0;
}
*/
