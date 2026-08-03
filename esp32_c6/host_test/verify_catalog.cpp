// verify_catalog - alimenta el DFA de tsxcatalog byte a byte con un JSON real
// del catalogo y vuelca las entradas en formato TSV (para diff contra Python).
//   uso: verify_catalog cat_A_0.json
#include <cstdio>
#include <cstdlib>
#include <vector>
#include "../tsxcatalog.h"

int main(int argc, char** argv) {
    if (argc != 2) { fprintf(stderr, "uso: verify_catalog cat.json\n"); return 2; }
    FILE* f = fopen(argv[1], "rb");
    if (!f) { fprintf(stderr, "no puedo abrir %s\n", argv[1]); return 2; }

    CatScanner s;
    cat_reset(&s);
    CatEntry e;
    int c, n = 0;
    while ((c = fgetc(f)) != EOF) {
        if (cat_feed(&s, (uint8_t)c, &e)) {
            printf("%s\t%u\t%u\n", e.name, e.sizeBytes, e.loadcmd);
            n++;
        }
    }
    if (cat_end(&s, &e)) {
        printf("%s\t%u\t%u\n", e.name, e.sizeBytes, e.loadcmd);
        n++;
    }
    fclose(f);
    fprintf(stderr, "%d entradas\n", n);
    return 0;
}
