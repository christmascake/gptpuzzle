#include <ctype.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <stdckdint.h>

static inline bool long_fits_int(const long n)
{
	return !ckd_add(&(int){ 0 }, n, 0);
}

int main(int argc, char *argv[])
{
	if (argc != 2) {
		fprintf(stderr, "error: exactly 1 argument required\n");
		return EXIT_FAILURE;
	}

	int	   sum	 = 0;
	char	  *start = &argv[1][0];
	char	  *sp;
	const long first_num = strtol(argv[1], &sp, 10);

	if ((start == sp) ||
	    (start != sp && *sp != ',' && *sp != '\0' && !isspace(*sp))) {
		fprintf(stderr, "error: malformed string\n");
		return EXIT_FAILURE;
	}

	if (!long_fits_int(first_num)) {
		fprintf(stderr, "error: number too large for int\n");
		return EXIT_FAILURE;
	}

	sum += (int)first_num;

	while (*sp != '\0') {
		while (isspace(*sp)) sp++;
		if (*sp == '\0')
			break;

		if (*sp == ',')
			sp++;

		start = sp;

		errno	       = 0;
		const long num = strtol(start, &sp, 10);

		if (start == sp) {
			fprintf(stderr, "error: malformed string\n");
			return EXIT_FAILURE;
		}

		if (long_fits_int(num)) {
			if (ckd_add(&sum, sum, num)) {
				fprintf(stderr,
					"error: sum too large for int\n");
				return EXIT_FAILURE;
			}
		} else {
			fprintf(stderr, "error: number too large for int\n");
			return EXIT_FAILURE;
		}
	}

	printf("%d\n", sum);

	return EXIT_SUCCESS;
}
