#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char *inc_buf(char *buf, size_t *size)
{
	char *tmp = realloc(buf, (*size + 1) * sizeof(*buf));
	if (!tmp) {
		fprintf(stderr, "inc_buf: realloc failed\n");
		free(buf);
		exit(EXIT_FAILURE);
	}

	(*size)++;
	return tmp;
}

void print_escape(const char *str, const size_t line_count, const size_t size)
{
	printf("buf_size: %zu, line_count: %zu, strlen: %zu, str: \"", size,
	       line_count, strlen(str));

	for (size_t i = 0; i < size; i++) {
		switch (str[i]) {
		case '\n': printf("\\n"); break;
		case '\0': printf("\\0"); break;
		default: putchar(str[i]);
		}
	}

	puts("\"");
}

void uniq_lines(void)
{
	char  *buf	  = NULL;
	size_t buf_size	  = 0;
	size_t line_count = 0;

	int c = 0;
	while ((c = getchar()) != EOF) {
		if (c == '\0') {
			fprintf(stderr,
				"error: '\\0' is not allowed in input\n");
			free(buf);
			exit(EXIT_FAILURE);
		}

		buf = inc_buf(buf, &buf_size);

		if ((char)c == '\n') {
			buf[buf_size - 1] = '\0';
			line_count++;
		} else {
			buf[buf_size - 1] = (char)c;
		}
	}

	if (ferror(stdin)) {
		perror("getchar");
		free(buf);
		exit(EXIT_FAILURE);
	}

	buf = inc_buf(buf, &buf_size);

	if (buf[buf_size - 1] != '\n')
		line_count++;

	buf[buf_size - 1] = '\0';

	char **lines = malloc(line_count * sizeof(char *));
	if (!lines) {
		fprintf(stderr, "malloc failed\n");
		free(buf);
		exit(EXIT_FAILURE);
	}

	int t = 0;
	for (char *p = buf; p < (char *)(buf + buf_size);
	     p += (strlen(p) + 1)) {
		lines[t] = p;
		t++;
	}

	// for every line total
	for (size_t i = 0; i < line_count; i++) {
		bool found = false;

		// for every line up until me
		for (size_t j = 0; j < i; j++) {
			if (strcmp(lines[i], lines[j]) == 0) {
				found = true;
				break;
			}
		}

		if (!found)
			puts(lines[i]);
	}

	free(lines);
	free(buf);
}

int main(void)
{
	uniq_lines();
	return EXIT_SUCCESS;
}
