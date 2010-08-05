/* -*- mode: C; indent-tabs-mode: nil; c-basic-offset: 2 c-style: "BSD" -*- */
/*
 * delta.c - byte-oriented delta compression implementation
 *
 * Copyright (C) 2005 Satoru Takabayashi <satoru@namazu.org> 
 * Copyright (C) 2005 Keisuke Nishida <knishida@open-cobol.org>
 *      All rights reserved.
 *      This is free software with ABSOLUTELY NO WARRANTY.
 * 
 *  You can redistribute it and/or modify it under the terms of 
 *  the GNU General Public License version 2.
 */

#include <ruby.h>
#include <assert.h>

#ifndef RARRAY_PTR
# define RARRAY_PTR(str) (RARRAY(str)->ptr)
#endif
#ifndef RARRAY_LEN
# define RARRAY_LEN(str) (RARRAY(str)->len)
#endif

typedef void (*CodeFunc)(VALUE *p, int i, int *prev);

static inline void
decode(VALUE *p, int i, int *prev)
{
  int this;
  if (TYPE(p[i]) != T_FIXNUM) {
    rb_raise(rb_eTypeError, "wrong argument type (fixnum required)");
  }
  this = FIX2INT(p[i]);
  p[i] = INT2FIX(this + *prev);
  *prev = FIX2INT(p[i]);
}

static inline void
encode(VALUE *p, int i, int *prev)
{
  int this;
  if (TYPE(p[i]) != T_FIXNUM) {
    rb_raise(rb_eTypeError, "wrong argument type (fixnum required)");
  }

  this = FIX2INT(p[i]);
  p[i] = INT2FIX(this - *prev);
  if (FIX2INT(p[i]) < 0) {
    rb_raise(rb_eArgError, "Encode failed: value becomes minus");
  }
  *prev = this;
}

static VALUE
rb_delta_code_tuples(VALUE obj, VALUE list, 
                     VALUE delta_size, VALUE unit_size, CodeFunc code)
{
  enum { PREV_MAX = 128 };
  int i, j;
  int dsize;
  int usize;
  long len;
  int prev[PREV_MAX];
  VALUE *p;

  if (!(TYPE(list) == T_ARRAY && TYPE(delta_size) == T_FIXNUM &&
        TYPE(unit_size) == T_FIXNUM && FIX2INT(delta_size) < PREV_MAX ))
  {
    rb_raise(rb_eTypeError, "wrong argument type");
  }

  dsize = FIX2INT(delta_size);
  usize = FIX2INT(unit_size);
  len = RARRAY_LEN(list);
  if (!(len % usize == 0 && dsize <= usize)) {
    rb_raise(rb_eArgError, "wrong argument size");
  }
  p = RARRAY_PTR(list); 
  memset(prev, 0, sizeof(int) * dsize);
  for (i = 0; i < len; i += usize) {
    for (j = 0; j < dsize; j++) {
      code(p, i + j, prev + j);
    }
  }
  return list;
}

static VALUE
rb_delta_decode_tuples(VALUE obj, VALUE list, 
                       VALUE delta_size, VALUE unit_size)
{
  return rb_delta_code_tuples(obj, list, delta_size, unit_size, decode);
}

static VALUE
rb_delta_encode_tuples(VALUE obj, VALUE list, 
                       VALUE delta_size, VALUE unit_size)
{
  return rb_delta_code_tuples(obj, list, delta_size, unit_size, encode);
}

static VALUE
rb_delta_code_fixnums(VALUE obj, VALUE list, CodeFunc code)
{
  int i;
  long len;
  VALUE *p; 
  int prev = 0;
  if (TYPE(list) != T_ARRAY) {
    rb_raise(rb_eTypeError, "wrong argument type");
  }
  p = RARRAY_PTR(list);
  len = RARRAY_LEN(list);
  for (i = 0; i < len; i++) {
    code(p, i, &prev);
  }
  return list;
}

static VALUE
rb_delta_decode_fixnums(VALUE obj, VALUE list)
{
  rb_delta_code_fixnums(obj, list, decode);
}

static VALUE
rb_delta_encode_fixnums(VALUE obj, VALUE list)
{
  rb_delta_code_fixnums(obj, list, encode);
}

void Init_delta()
{
  VALUE mGonzui, mDelta;
  mGonzui = rb_define_module("Gonzui");
  mDelta = rb_define_module_under(mGonzui, "DeltaDumper");
  rb_define_module_function(mDelta, "encode_tuples", 
                            rb_delta_encode_tuples, 3);
  rb_define_module_function(mDelta, "decode_tuples", 
                            rb_delta_decode_tuples, 3);
  rb_define_module_function(mDelta, "encode_fixnums", 
                            rb_delta_encode_fixnums, 1);
  rb_define_module_function(mDelta, "decode_fixnums",
                            rb_delta_decode_fixnums, 1);
}


