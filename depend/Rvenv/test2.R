#!/usr/bin/Rvenv-3.1.1 -p .Rvenv-test -l library.test
#!/usr/bin/env Rscript-3.1.1
cat("---------------------\n")
library(foreach)
scriptName <- if (exists("Rvenv.file.path")) Rvenv.file.path else ""
scriptDir <- if (exists("Rvenv.dir.path")) Rvenv.dir.path else ""
cat(sprintf("Begin %s\n", scriptName))
cat(sprintf("+ Dir %s\n", scriptDir))
cat(sprintf("+ Running: %sinteractive\n", if (interactive()) "" else "non-"))
cat("+ browser()\n")
browser() # Add -i or -I to interpreter line to enable
stdin <- file("stdin", "r")
if (!isatty(stdin())) {
	lines <- readLines(stdin)
} else {
	lines <- c()
}
nlines <- length(lines)
cat(sprintf("+ %d lines from stdin\n", nlines))
if (nlines > 0) {
	invisible(foreach(n = 1:nlines) %do%
		cat(sprintf("%6d %s\n", n, lines[n])))
}
cat(sprintf("End %s\n", scriptName))
