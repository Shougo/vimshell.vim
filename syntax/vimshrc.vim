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

syn match   VimShellRcCommand               '\%(^\|[;|]\)\s*\zs[[:alnum:]_.][[:alnum:]_.-]\+' contained
syn match   VimShellRcVariable          '$\h\w*' contained
syn match   VimShellRcVariable          '$$\h\w*' contained
syn region   VimShellRcVariable  start=+${+ end=+}+ contained
syn region   VimShellRcString   start=+'+ end=+'+ oneline contained
syn region   VimShellRcString   start=+"+ end=+"+ contains=VimShellQuoted oneline contained
syn region   VimShellRcString   start=+`+ end=+`+ oneline contained
syn match   VimShellRcString   '[''"`]$' contained
syn match   VimShellRcComment   '#.*$' contained
syn match   VimShellRcConstants         '[+-]\=\<\d\+\>' contained
syn match   VimShellRcConstants         '[+-]\=\<0x\x\+\>' contained
syn match   VimShellRcConstants         '[+-]\=\<0\o\+\>' contained
syn match   VimShellRcConstants         '[+-]\=\d\+#[-+]\=\w\+\>' contained
syn match   VimShellRcConstants         '[+-]\=\d\+\.\d\+\([eE][+-]\?\d\+\)\?\>' contained
syn match   VimShellRcArguments         '\s-\=-[[:alnum:]-]\+=\=' contained
syn match   VimShellRcQuoted            '\\.' contained
syn match   VimShellRcSpecial           '[|<>;&;]' contained
if vimshell#iswin()
    syn match   VimShellRcArguments         '\s/[?:,_[:alnum:]]\+\ze\%(\s\|$\)' contained
    syn match   VimShellRcDirectory         '\%(\f\s\?\)\+[/\\]\ze\%(\s\|$\)'
else
    syn match   VimShellRcDirectory         '\%(\f\s\?\)\+/\ze\%(\s\|$\)'
endif

syn region   VimShellRcVimShellScriptRegion start='\zs\<\f\+' end='\zs$' contains=VimShellRcCommand,VimShellRcVariable,VimShellRcString,VimShellRcComment,VimShellRcConstants,VimShellRcArguments,VimShellRcQuoted,VimShellRcSpecial,VimShellRcDirectory
syn region   VimShellRcCommentRegion  start='#' end='\zs$'
syn cluster  VimShellRcBodyList contains=VimShellRcVimShellScriptRegion,VimShellRcComment

unlet! b:current_syntax
syn include @VimShellRcVimScript syntax/vim.vim
syn region VimShellRcVimScriptRegion start=-\<vexe\s\+\z(["']\)\zs$- end=+\z1\zs$+ contains=@VimShellRcVimScript
syn cluster VimShellRcBodyList add=VimShellRcVimScriptRegion

hi def link VimShellRcQuoted Special
hi def link VimShellRcString Constant
hi def link VimShellRcArguments Type
hi def link VimShellRcConstants Constant
hi def link VimShellRcSpecial PreProc
hi def link VimShellRcVariable Comment
hi def link VimShellRcComment Identifier
hi def link VimShellRcCommentRegion Identifier
hi def link VimShellRcNormal Normal

hi def link VimShellRcCommand Statement
hi def link VimShellRcDirectory Preproc

let b:current_syntax = 'vimshrc'
