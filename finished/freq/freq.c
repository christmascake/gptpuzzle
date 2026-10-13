#include <errno.h>
#include <stdlib.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdint.h>
#include <ctype.h>
#include <string.h>

int main(int argc, char *argv[])
{
	if (argc != 2) {
		fprintf(stderr,
			"incorrect number of arguments, usage: \"%s 'filename'\"\n",
			argv[0]);
		return EXIT_FAILURE;
	}

	FILE *f = fopen(argv[1], "rb");

	if (f == NULL) {
		fprintf(stderr, "%s: failed to open %s: %s\n", argv[0], argv[1],
			strerror(errno));
		return EXIT_FAILURE;
	}

	int64_t byte_count[256] = { 0 };
	int	c;
	while ((c = fgetc(f)) != EOF) {
		byte_count[c]++;
	}

	if (ferror(f)) {
		fprintf(stderr, "error reading file: %s\n", argv[1]);
		fclose(f);
		return EXIT_FAILURE;
	}

	for (int i = 0; i < 256; i++) {
		if (byte_count[i] && isprint(i)) {
			printf("Byte: 0x%x, Count: %" PRId64
			       ", Character: '%c'\n",
			       i, byte_count[i], i);
		} else if (byte_count[i]) {
			printf("Byte: 0x%x, Count: %" PRId64 "\n", i,
			       byte_count[i]);
		}
	}

	fclose(f);
	return EXIT_SUCCESS;
}
