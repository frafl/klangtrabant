

# Klangtrabant
Klangtrabant is a lua library and LuaLaTeX package for creating
books for the so called Ting pen.
There is now experimental support for tiptoi patterns
(but no logic support) as well.

Relation to Tingeltangel and tttool
----
Major parts of this software were taken from Tingeltangel (see
https://www.ting-el-tangel.de)
and ported from Java to Lua. Thus its authors (mostly Martin Dames
but also Jesper Zedlitz) are listed as Copyright holders in the
respective source files. Please do not blame them for any bugs in
Klangtrabant. Information on valid tiptoi code patterns where used from
tttool as well, but no further code.

Why another tool if Tingeltangel works well?
----
Since TikZ/PGF offers a great way of creating the crucial dot patterns
for the Ting pen and nowadays LuaTeX allows easy programming
within LaTeX, a Lua library allows an author to create the page layout
and interactions with the same tools and store them at the same place.
Furthermore the assembler dialect used for the Ting is very restricted
and thus generating scripts algorithmically seems reasonable. This is
a lot harder for occasional projects with Java (or another JVM
language) then with a scripting language like Lua.

Does this software completely replace Tingeltangel?
----
No, for instance Klangtrabant does not have and will not have
any tools for managing book collections or deploying to the Ting.
Furthermore it does not have an emulator.
Klangtrabant is best for creating new books with many pages or with
a very complex program logic.

How to install (under most Linux/Unix systems)
----
 * Clone this repo to a subdirectory of your ~/texmf folder.
 * Install Lua and current versions of lpeg and re, make sure
 lua is in your PATH
 * LuaTeX can be called as texlua and comes with lpeg. If you use that,
 download re separately e.g.
 from https://raw.githubusercontent.com/LuaDist/lpeg/master/re.lua
 to the Klangtrabant folder or use the same version of a normal
 lua binary (e.g. Lua 5.3 for texlua from LuaLaTeX 1.20) to
 install re via luarocks
 * Create a symbolic link for the executable script:
 ln -s ~/texmf/wherever/you/cloned/klangtrabant.sh ~/bin/klangtrabant

How to use ...
----
 * ... the executable: simple type klangtrabant help
 * ... the LaTeX package: see example:
 a simple make will produce 4 files:
 a printable background, a printable foreground,
 a fake foreground that can be placed on the background
 and a combined PDF. This last PDF is a preview for what you will
 get when you print foreground on background. However you should
 not print the combined PDF as this may destroy the dot patterns due
 to optimizations done by many printers (or their drivers).

License
----
 * This software is licensed under GPLv2+, see each file header.
 * If you need a more permissive license (e.g. BSD-style) for the
 LaTeX part and pattern generation, please contact the author.

TODO
----
 * further testing
 * compatibility to Tingeltangel templates (mod,rnd,lock etc.)
 * Expand LuaLaTex package, e.g., more functionality accessible from
 LaTeX
 * document API
 * extended compatibility with tiptoi

