#!/usr/bin/Rvenv-3.1.1 -p .Rvenv-test -l library.test
#!/usr/bin/env Rscript-3.1.1
cat("---------------------\n")
scriptName <- if (exists("Rvenv.file.path")) Rvenv.file.path else ""
scriptDir <- if (exists("Rvenv.dir.path")) Rvenv.dir.path else ""
cat(sprintf("Begin %s\n", scriptName))
cat(sprintf("+ Dir %s\n", scriptDir))
cat(sprintf("+ Running: %sinteractive\n", if (interactive()) "" else "non-"))
cat("+ browser()\n")
browser() # Add -i or -I to interpreter line to enable
cat("+ Library paths are:\n")
for(d in .libPaths()) {
	cat(sprintf("  %s\n", d))
}
args = commandArgs(trailingOnly=TRUE)
argc = length(args)
cat(sprintf("+ There are %d args\n", argc))
if (argc > 0) {
	for (i in 1:argc) {
		cat(sprintf("  Arg%i is %s\n", i, args[i]))
	}
}
cat("+ Loading bender... ")
library(bender)
cat("done\n")
cat("+ Success\n")
cat(sprintf("End %s\n", scriptName))
