book.pdf: book_bg.pdf book_fg_fake.pdf book_fg.pdf
	pdftk book_fg_fake.pdf background book_bg.pdf output book.pdf

book_bg.pdf: book.tex
	lualatex -jobname book_bg "\input book.tex"

book_fg_fake.pdf: book.tex
	lualatex -jobname book_fg_fake "\def\klangtrabantfill{}\def\klangtrabantdotpatterns{}\input book.tex"

book_fg.pdf: book.tex
	lualatex -jobname book_fg "\def\klangtrabantdotpatterns{}\input book.tex"


