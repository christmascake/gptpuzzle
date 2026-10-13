#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[])
{
	// REQ1
	if (argc != 2) {
		fprintf(stderr, "error: exactly 1 argument required.");
		return EXIT_FAILURE;
	}

	return EXIT_SUCCESS;
}
