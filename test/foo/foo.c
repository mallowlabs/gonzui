#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include "bar.h"

int foo (int a, int b);

/*
 * We use tab characters for test purpose. gonzui internally
 * converts tab characters into spaces and we need to test
 * the effect.
 */
int 
main (int argc, char **argv)
{
	printf("%d\n", foo(1, 2));
	return 0;
}

int
foo (int a, int b)
{
	return bar(a, b);
}

