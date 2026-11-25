/* SPDX-License-Identifier: 0BSD */
/* Independent, benign boot marker. No shell, network or filesystem access. */
#include <unistd.h>

int main(void)
{
	static const char message[] = "PUBLIC_SUBLEQ_BASELINE_OK\n";

	(void)write(STDOUT_FILENO, message, sizeof(message) - 1);
	for (;;)
		sleep(60);
}
