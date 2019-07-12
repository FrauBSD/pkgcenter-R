#!/usr/bin/Renv-3.1.1 -p .Renv-test -l library.test
#!/usr/bin/env Rscript-3.1.1
cat("---------------------\n")
library(foreach)
scriptName <- if (exists("Renv.file.path")) Renv.file.path else ""
cat(sprintf("Begin %s\n", scriptName))
stdin <- file("stdin", "r")
lines <- readLines(stdin)
nlines <- length(lines)
cat(sprintf("+ %d lines from stdin\n", nlines))
if (nlines > 0) {
	invisible(foreach(n = 1:nlines) %do%
		cat(sprintf("%6d %s\n", n, lines[n])))
}
cat(sprintf("End %s\n", scriptName))
