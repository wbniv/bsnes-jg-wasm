/*
 * libco backend for Emscripten / WebAssembly.
 *
 * byuu's libco v20 (bundled in bsnes-jg's deps/libco) has no wasm code path: its
 * dispatcher in libco.c matches no wasm architecture and falls through to
 * sjlj.c, which bootstraps a coroutine's stack with sigaltstack + raise(SIGUSR1)
 * — POSIX signal machinery Emscripten does not implement. So the stock core
 * cannot cooperatively thread (CPU / SMP / coprocessor) in the browser.
 *
 * Emscripten fibers give exactly libco's cooperative-thread semantics
 * (co_switch == emscripten_fiber_swap) on top of Asyncify stack-switching. This
 * file implements the libco API in those terms. It is dropped into
 * deps/libco/emscripten.c and #included by a patched libco.c under
 * `#elif defined(__EMSCRIPTEN__)`; the final link must pass -sASYNCIFY.
 *
 * bsnes-jg drives only co_active / co_create / co_derive / co_switch / co_delete
 * with a couple of shallow coroutines. Stacks are sized far above the native
 * Thread::Size (16 KiB on wasm32) because wasm frames plus the Asyncify shadow
 * stack are larger than a native machine stack; there are only a few coroutines,
 * so the extra memory is negligible.
 */
#define LIBCO_C
#include "libco.h"

#include <stdlib.h>
#include <emscripten/fiber.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef LIBCO_EM_CSTACK
#define LIBCO_EM_CSTACK  (1u << 20)   /* 1 MiB C stack per coroutine          */
#endif
#ifndef LIBCO_EM_ASTACK
#define LIBCO_EM_ASTACK  (1u << 18)   /* 256 KiB Asyncify shadow stack         */
#endif

typedef struct {
  emscripten_fiber_t fiber;
  void (*entry)(void);
  unsigned char* cstack;
  unsigned char* astack;
} co_em;

static co_em co_primary;          /* the context that exists before any co_create */
static co_em* co_running = 0;

/* libco entrypoints loop forever and never return; guard the impossible case. */
static void co_trampoline(void* udata) {
  co_em* t = (co_em*)udata;
  t->entry();
  for(;;) co_switch((cothread_t)&co_primary);
}

static void ensure_primary(void) {
  if(co_running) return;
  co_primary.astack = (unsigned char*)malloc(LIBCO_EM_ASTACK);
  emscripten_fiber_init_from_current_context(
    &co_primary.fiber, co_primary.astack, LIBCO_EM_ASTACK);
  co_running = &co_primary;
}

static co_em* co_setup(co_em* t, unsigned int size, void (*entry)(void)) {
  unsigned int cs = size < LIBCO_EM_CSTACK ? LIBCO_EM_CSTACK : size;
  if(!t->cstack) t->cstack = (unsigned char*)malloc(cs);
  if(!t->astack) t->astack = (unsigned char*)malloc(LIBCO_EM_ASTACK);
  t->entry = entry;
  emscripten_fiber_init(&t->fiber, co_trampoline, t,
    t->cstack, cs, t->astack, LIBCO_EM_ASTACK);
  return t;
}

cothread_t co_active(void) {
  ensure_primary();
  return (cothread_t)co_running;
}

cothread_t co_create(unsigned int size, void (*entry)(void)) {
  ensure_primary();
  co_em* t = (co_em*)calloc(1, sizeof(co_em));
  if(!t) return 0;
  return (cothread_t)co_setup(t, size, entry);
}

/* bsnes hands back a handle from a previous co_create to re-init it in place
 * (reusing its stacks); treat `memory` as that handle, matching how co_create's
 * return value is fed straight into co_derive in src/sfc.cpp. */
cothread_t co_derive(void* memory, unsigned int size, void (*entry)(void)) {
  ensure_primary();
  if(!memory) return 0;
  return (cothread_t)co_setup((co_em*)memory, size, entry);
}

void co_delete(cothread_t handle) {
  co_em* t = (co_em*)handle;
  if(!t || t == &co_primary) return;
  free(t->cstack);
  free(t->astack);
  free(t);
}

void co_switch(cothread_t handle) {
  co_em* prev = co_running;
  co_running = (co_em*)handle;
  emscripten_fiber_swap(&prev->fiber, &co_running->fiber);
}

int co_serializable(void) {
  return 0;
}

#ifdef __cplusplus
}
#endif
