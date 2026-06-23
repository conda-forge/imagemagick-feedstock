/*
 * MSVC compatibility smoke test for magick-baseconfig.h
 *
 * This file is compiled with cl.exe (MSVC) to verify that the
 * MagickCore headers are consumable from MSVC-based downstream
 * packages (e.g. libvips).
 *
 * Failures this test catches:
 *   - C2086/C2371: __restrict__ is not valid in MSVC;
 *     must be __restrict (single underscore).
 *   - C2065: ssize_t undeclared when not typedef'd in magick-baseconfig.h.
 */

// Required by MagickCore/magick-config.h
#define MAGICKCORE_QUANTUM_DEPTH 16
#define MAGICKCORE_HDRI_ENABLE 1

#include <MagickCore/MagickCore.h>

// Verify ssize_t is usable
static ssize_t test_ssize = -1;

// Verify _magickcore_restrict is usable as a qualifier
static int test_restrict(const int * _magickcore_restrict p) {
    return *p;
}

int main(void) {
    (void)test_ssize;
    int x = 42;
    return test_restrict(&x) == 42 ? 0 : 1;
}
