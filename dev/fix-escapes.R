# One-shot repair of R/normalize.R lines 105-122 (the .np_strip_joiners /
# .np_basic_clean block). Rewrites the block verbatim so the quote class is
# written as \u escapes and the [[:punct:]] rule is restored.
p <- "R/normalize.R"
s <- readLines(p, encoding = "UTF-8", warn = FALSE)

start <- grep("^# Written with .u escapes", s)
end   <- grep("^\\.np_basic_clean <- function", s)
end   <- end[1] + 8L                       # through the closing brace
stopifnot(length(start) == 1L, s[end] == "}")
cat("rewriting lines", start, "-", end, "\n")

blk <- c(
'#',
'# The quote class is written with \\u escapes rather than literal glyphs so this',
'# file stays pure ASCII. De-accenting runs before this in .np_basic_clean() and',
'# already folds the curly forms to a plain apostrophe; the rest are belt and',
'# braces for any caller that cleans a string directly.',
'.np_strip_joiners <- function(x) {',
'  x <- gsub("[\'\\u2018\\u2019\\u02BC\\u00B4`]", "", x, perl = TRUE)',
'  gsub("(?<=[A-Za-z0-9])\\\\.(?=[A-Za-z0-9])", "", x, perl = TRUE)',
'}',
'',
'.np_basic_clean <- function(x) {',
'  x <- toupper(as.character(x))',
'  x <- stringi::stri_trans_general(x, "Latin-ASCII") # de-accent',
'  x <- gsub("&", " AND ", x, fixed = TRUE)',
'  x <- .np_strip_joiners(x)          # delete, do not space -- see above',
'  x <- gsub("[[:punct:]]", " ", x)   # every other mark separates tokens',
'  x <- gsub("[^A-Z0-9 ]", " ", x)',
'  stringr::str_squish(x)',
'}')

s <- c(s[seq_len(start - 1L)], blk, s[(end + 1L):length(s)])
writeLines(s, p, useBytes = TRUE)
cat("done\n")
