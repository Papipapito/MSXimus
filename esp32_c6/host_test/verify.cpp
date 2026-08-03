// verify - driver de PC para verificar tsx2cvs byte-exacto contra el Python.
//   uso: verify entrada.tsx salida.cvs
// (Arduino ignora este subdirectorio; solo se compila con g++ en el PC.)
#include <cstdio>
#include <cstdlib>
#include <vector>
#include "../tsx2cvs.h"

int main(int argc, char** argv) {
    if (argc != 3) { fprintf(stderr, "uso: verify in.tsx out.cvs\n"); return 2; }
    FILE* f = fopen(argv[1], "rb");
    if (!f) { fprintf(stderr, "no puedo abrir %s\n", argv[1]); return 2; }
    fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    std::vector<uint8_t> in((size_t)n);
    if (fread(in.data(), 1, (size_t)n, f) != (size_t)n) { fclose(f); return 2; }
    fclose(f);

    std::vector<uint8_t> out;
    const char* err = tsx2cvs(in.data(), in.size(), out);
    if (err) { fprintf(stderr, "ERROR: %s\n", err); return 1; }

    FILE* g = fopen(argv[2], "wb");
    if (!g) { fprintf(stderr, "no puedo escribir %s\n", argv[2]); return 2; }
    fwrite(out.data(), 1, out.size(), g);
    fclose(g);
    printf("%s -> %zu bytes CVS1\n", argv[1], out.size());
    return 0;
}
