#include <errno.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[])
{
	// REQ1
	if (argc != 2) {
		fprintf(stderr, "error: exactly 1 argument required");
		return EXIT_FAILURE;
	}

	char *foo;
	printf("%ld", (strtol(argv[1], &foo, 10) * 2));
	perror("");

	return EXIT_SUCCESS;
}
