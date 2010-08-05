/* -*- mode: C; indent-tabs-mode: nil; c-basic-offset: 2 c-style: "BSD" -*- */
/*
 * autopack.c - C functions for AutoPack module.
 *
 * Copyright (C) 2005 Satoru Takabayashi <satoru@namazu.org> 
 *      All rights reserved.
 *      This is free software with ABSOLUTELY NO WARRANTY.
 * 
 *  You can redistribute it and/or modify it under the terms of 
 *  the GNU General Public License version 2.
 */

#include <ruby.h>

#ifndef RSTRING_PTR
# define RSTRING_PTR(s) (RSTRING(s)->ptr)
#endif

static VALUE
rb_autopack_pack_fixnum(VALUE obj, VALUE value)
{
    int n;
    unsigned char str[4];
    if (TYPE(value) != T_FIXNUM) {
        rb_raise(rb_eTypeError, "Fixnum expected");
    }
    n = FIX2INT(value);
    str[0] = (n >> 24) & 0xff;
    str[1] = (n >> 16) & 0xff;
    str[2] = (n >>  8) & 0xff;
    str[3] =  n        & 0xff;
    return rb_str_new(str, 4);
}

static VALUE
rb_autopack_pack_id2(VALUE obj, VALUE id1, VALUE id2)
{
    int n1, n2;
    unsigned char str[8];
    if (!(TYPE(id1) == T_FIXNUM && TYPE(id2) == T_FIXNUM)) {
        rb_raise(rb_eTypeError, "Fixnum expected");
    }
    n1 = FIX2INT(id1);
    n2 = FIX2INT(id2);
    str[0] = (n1 >> 24) & 0xff;
    str[1] = (n1 >> 16) & 0xff;
    str[2] = (n1 >>  8) & 0xff;
    str[3] =  n1        & 0xff;
    str[4] = (n2 >> 24) & 0xff;
    str[5] = (n2 >> 16) & 0xff;
    str[6] = (n2 >>  8) & 0xff;
    str[7] =  n2        & 0xff;
    return rb_str_new(str, 8);
}

static VALUE
rb_autopack_unpack_fixnum(VALUE obj, VALUE value)
{
    int n;
    unsigned char *str;
    if (TYPE(value) != T_STRING) {
        rb_raise(rb_eTypeError, "String expected");
    }
    str = RSTRING_PTR(value);
    n = (str[0] << 24) + (str[1] << 16) + (str[2] << 8) + str[3];
    return INT2FIX(n);
}

void Init_autopack()
{
  VALUE mGonzui, mAutoPack;
  mGonzui = rb_define_module("Gonzui");
  mAutoPack = rb_define_module_under(mGonzui, "AutoPack");

  rb_define_module_function(mAutoPack, "pack_id", 
                            rb_autopack_pack_fixnum, 1);
  rb_define_module_function(mAutoPack, "unpack_id", 
                            rb_autopack_unpack_fixnum, 1);

  rb_define_module_function(mAutoPack, "pack_fixnum", 
                            rb_autopack_pack_fixnum, 1);
  rb_define_module_function(mAutoPack, "unpack_fixnum", 
                            rb_autopack_unpack_fixnum, 1);
  rb_define_module_function(mAutoPack, "pack_id2", 
                            rb_autopack_pack_id2, 2);
}


