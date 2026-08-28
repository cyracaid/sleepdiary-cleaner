# helper-locale.R — force UTF-8 so rendered-doc comparisons byte-match.
# R CMD check / bare Rscript often start with LC_CTYPE="C" on macOS CI;
# without this, Chinese literals in tools/render_docs.R get native-encoded
# and identical() against UTF-8 files fails spuriously.
local({ suppressWarnings(Sys.setlocale("LC_CTYPE", "en_US.UTF-8")) })
