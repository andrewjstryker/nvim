#! /usr/bin/env -S awk -f
##-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-##
## generate-help.awk
##
# Makefile help generator
# https://github.com/andrewjstryker/makefile-helper
##
## As we use this file as the source for generating embeded files, there
## a couple quirks:
##  1. Prefix lines with '##' to avoid passing them into the embedded version.
##  2. End non-comment lines with semicolons or closing braces to prevent the
##     AWK interpretter from becoming confused.
#
##
## ANSI color codes: https://en.wikipedia.org/wiki/ANSI_escape_code
##
##-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-##

BEGIN {
        # split fields from colon to either #> or #!, just on #>, or ?=
        FS = "(:.*#[>!]|#>|?=)";

        # track if any targets require special privileges
        special = 0;

        # track environment variables
        env_counter = 0;
        env_section = 0;

        # string formats, collected here for easier editing
        normal_fmt       = "\t\033[36m%-15s\033[0m %s\n";
        special_fmt      = "\t\033[31m%-15s\033[0m %s\n";
        continuation_fmt = "\t%17s%s\n";
        env_var_val      = "\033[37m%s \033[93m%s\033[0m";
        env_var_fmt      = "\t%-15s %s\n";
}

# environment variables
/^[a-zA-Z0-9_]+\s\?=.*#>/ {
        env_counter += 1;
        env_vars[env_counter] = sprintf(env_var_fmt,
                sprintf(env_var_val, $1, $2),
                $3);
        env_section = 1;
        next;
}

# continuation message within an environment variable block
env_section && /^\t#[>!]/ {
        env_counter += 1;
        env_vars[env_counter] = sprintf(continuation_fmt,
               " ",
               gensub(/^\t#[>!] ?(.*)/, "\\1", "g", $0));
        next;
}

# reset environment flag
{
        env_section = 0;
}

# full length help message
/^#>/ {
        printf("%s\n", gensub(/^#> ?(.*)/, "\\1", "g", $0));
        next;
}

# continuation messages
/^\t#[>!]/ {
        printf(continuation_fmt,
               " ",
               gensub(/^\t#[>!] ?(.*)/, "\\1", "g", $0));
        next;
}

# targets that might require elevated priveleges
/^[^[:space:]:]+([[:space:]]+[^[:space:]:]+)*[[:space:]]*:.*#!/ {
        printf(special_fmt, $1, $2);
        special = 1;
        next;
}

# normal targets
/^[^[:space:]:]+([[:space:]]+[^[:space:]:]+)*[[:space:]]*:.*#>/ {
        printf(normal_fmt, $1, $2);
        next;
}

# allow users to control the location of environment variables
/^#env_vars:/ {
        print_env();
}

END {
        print_env();

        if (special) {
                printf("\nTargets in \033[31mred\033[0m ");
                printf("might require special priveleges.\n");
        }
}

function print_env() {
        if (env_counter) {
                printf("\nThis Makefile respects the following environment ");
                printf("variables, shown with their values:\n\n");
                for (i = 1; i <= env_counter; ++i) printf("%s", env_vars[i]);

                # reset the counter to prevent duplication
                env_counter = 0;
        }
}

## vim: et sts=8
