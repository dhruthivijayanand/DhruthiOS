#ifndef DHRUTHIOS_COMMANDS_H
#define DHRUTHIOS_COMMANDS_H

/* line points to at least length readable bytes; no NUL terminator required.
 * Zero length accepts a null pointer. Nonzero length with null is rejected.
 * Returns immutable static text; no allocation, I/O, or changes to input. */
const char *command_response(const char *line, unsigned length);

#endif