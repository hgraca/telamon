# BOOTSTRAP

NEVER read nor modify any file with "no-vcs" in the name, unless explicitly directed to read it.
NEVER read nor modify any folder with "no-vcs" in the name, unless explicitly directed to read it.

## MANDATORY START SEQUENCE

Read all files matching `.ai/context*/*.md` (if they exist) to gather context and agent instructions

If any rule cannot be satisfied:
STOP and report conflict.

Do not proceed without loading these files into context.
