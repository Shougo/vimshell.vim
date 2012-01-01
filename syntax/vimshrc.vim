"=============================================================================
" FILE: syntax/vimshrc.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 18 Apr 2010
" Usage: Just source this file.
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
"=============================================================================

if version < 700
  syntax clear
elseif exists('b:current_syntax')
  finish
endif

syntax match   VimShellRcCommand               '\%(^\|[;|]\)\s*\zs[[:alnum:]_.][[:alnum:]_.-]\+' contained
syntax match   VimShellRcVariable          '$\h\w*' contained
syntax match   VimShellRcVariable          '$$\h\w*' contained
syntax region   VimShellRcVariable  start=+${+ end=+}+ contained
syntax region   VimShellRcString   start=+'+ end=+'+ oneline contained
syntax region   VimShellRcString   start=+"+ end=+"+ contains=VimShellQuoted oneline contained
syntax region   VimShellRcString   start=+`+ end=+`+ oneline contained
syntax match   VimShellRcString   '[''"`]$' contained
syntax match   VimShellRcComment   '#.*$' contained
syntax match   VimShellRcConstants         '[+-]\=\<\d\+\>' contained
syntax match   VimShellRcConstants         '[+-]\=\<0x\x\+\>' contained
syntax match   VimShellRcConstants         '[+-]\=\<0\o\+\>' contained
syntax match   VimShellRcConstants         '[+-]\=\d\+#[-+]\=\w\+\>' contained
syntax match   VimShellRcConstants         '[+-]\=\d\+\.\d\+\([eE][+-]\?\d\+\)\?\>' contained
syntax match   VimShellRcArguments         '\s-\=-[[:alnum:]-]\+=\=' contained
syntax match   VimShellRcQuoted            '\\.' contained
syntax match   VimShellRcSpecial           '[|<>;&;]' contained
if vimshell#iswin()
    syntax match   VimShellRcArguments         '\s/[?:,_[:alnum:]]\+\ze\%(\s\|$\)' contained
    syntax match   VimShellRcDirectory         '\%(\f\s\?\)\+[/\\]\ze\%(\s\|$\)'
else
    syntax match   VimShellRcDirectory         '\%(\f\s\?\)\+/\ze\%(\s\|$\)'
endif

syntax region   VimShellRcVimShellScriptRegion start='\zs\<\f\+' end='\zs$' contains=VimShellRcCommand,VimShellRcVariable,VimShellRcString,VimShellRcComment,VimShellRcConstants,VimShellRcArguments,VimShellRcQuoted,VimShellRcSpecial,VimShellRcDirectory
syntax region   VimShellRcCommentRegion  start='#' end='\zs$'
syntax cluster  VimShellRcBodyList contains=VimShellRcVimShellScriptRegion,VimShellRcComment

unlet! b:current_syntax
syntax include @VimShellRcVimScript syntax/vim.vim
syntax region VimShellRcVimScriptRegion start=-\<vexe\s\+\z(["']\)\zs$- end=+\z1\zs$+ contains=@VimShellRcVimScript
syntax cluster VimShellRcBodyList add=VimShellRcVimScriptRegion

highlight default link VimShellRcQuoted Special
highlight default link VimShellRcString Constant
highlight default link VimShellRcArguments Type
highlight default link VimShellRcConstants Constant
highlight default link VimShellRcSpecial PreProc
highlight default link VimShellRcVariable Comment
highlight default link VimShellRcComment Identifier
highlight default link VimShellRcCommentRegion Identifier
highlight default link VimShellRcNormal Normal

highlight default link VimShellRcCommand Statement
highlight default link VimShellRcDirectory Preproc

let b:current_syntax = 'vimshrc'
