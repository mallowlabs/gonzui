/* -*- mode: C; indent-tabs-mode: nil; c-basic-offset: 2 c-style: "BSD" -*- */
/* 
 * texttokenizer.c - a simple text tokenizer
 *
 * Copyright (C) 2005 Satoru Takabayashi <satoru@namazu.org> 
 * Copyright (C) 2005 Keisuke Nishida <knishida@open-cobol.org>
 *     All rights reserved.
 *     This is free software with ABSOLUTELY NO WARRANTY.
 * 
 * You can redistribute it and/or modify it under the terms of 
 * the GNU General Public License version 2.
 *
 *
 */

#include <assert.h>
#include <ruby.h>

#ifndef RSTRING_PTR
# define RSTRING_PTR(s) (RSTRING(s)->ptr)
#endif
#ifndef RSTRING_LEN
# define RSTRING_LEN(s) (RSTRING(s)->len)
#endif

static inline int utf8len(const unsigned char *s, const unsigned char *eot)
{
  int len = 0;
  if (*s < 0x80) {
    len = 1;
  } else if ((s + 1 < eot) && (*s & 0xe0) == 0xc0) {
    len = 2;
  } else if ((s + 2 < eot) && (*s & 0xf0) == 0xe0) {
    len = 3;
  } else if ((s + 3 < eot) && (*s & 0xf8) == 0xf0) {
    len = 4;
  } else if ((s + 4 < eot) && (*s & 0xfc) == 0xf8) {
    len = 5;
  } else if ((s + 5 < eot) && (*s & 0xfe) == 0xfc) {
    len = 6;
  } else {
    rb_raise(rb_eArgError, "invalid UTF-8 character");
  }
  return len;
}

static inline unsigned char *
skip(unsigned char *s, unsigned char *eot)
{
  for (; s < eot; s++)
    if (isalnum(*s) || *s >= 0x80)
      break;
  return s;
}

/*
 * Iterate over each word.
 * word:  [a-zA-Z0-9]+ or single multi-byte UTF-8 character
 */
static VALUE texttokenizer_each_word(VALUE obj, VALUE text)
{
  VALUE str;
  unsigned char *s, *beg, *eot;

  str = rb_obj_as_string(text);
  beg = RSTRING_PTR(str);
  eot = beg + RSTRING_LEN(str);
  s = skip(beg, eot);

  while (s < eot) {
    unsigned char *b = s;
    if (*s >= 0x80) {
      s += utf8len(s, eot);
    } else {
      for (; s < eot; s++)
        if (!((isalnum(*s) || *s == '_')))
          break;
    }
    rb_yield_values(2, rb_str_new(b, s - b), INT2FIX(b - beg));
    s = skip(s, eot);
  }
  return Qnil;
}

void Init_texttokenizer()
{
  VALUE mGonzui, mTextTokenizer;
  mGonzui = rb_define_module("Gonzui");
  mTextTokenizer = rb_define_module_under(mGonzui, "TextTokenizer");

  rb_define_module_function(mTextTokenizer, "each_word",
                            texttokenizer_each_word, 1);
}
