"=============================================================================
" FILE: syntax/vimshell.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>(Modified)
" Last Modified: 05 Jul 2009
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
" Version: 3.5, for Vim 7.0
"-----------------------------------------------------------------------------
" ChangeLog: "{{{
"   3.5:
"     - Added secondary prompt.
"     - Improved arguments on Windows.
"
"   3.4:
"     - Improved quote and error.
"     - Supports system variables.
"
"   3.3:
"     - Added keywords.
"     - Improved environment variables.
"     - Improved quote.
"
"   3.2:
"     - Supports exponential digits.
"
"   3.1:
"     - Optimized pattern.
"
"   3.0:
"     - Added VimShellErrorHidden.
"     - Added VimShellError.
"
"   2.9:
"     - Implemented VimShellComment.
"     - Improved VimShellDirectory.
"     - Added VimShellSpecial.
"     - Improved VimShellConstants.
"
"   2.8:
"     - Improved VimShellArguments color on Windows.
"     - Improved VimShellString.
"
"   2.7:
"     - Improved VimShellPrompt color on console.
"     - Improved VimShellDirectory color.
"     - Added VimShellDotFiles color.
"     - Improved VimShellVariable color.
"     - Improved VimShellArguments color.
"
"   2.6:
"     - Improved VimShellSpecial color.
"     - Improved VimShellExe color.
"     - Improved VimShellSocket color.
"
"   2.5:
"     - Improved prompt color when non gui.
""}}}
"-----------------------------------------------------------------------------
" TODO: "{{{
"     - Nothing.
""}}}
" Bugs"{{{
"     -
""}}}
"=============================================================================

if version < 700
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

execute 'syn match VimShellPrompt ' . "'".g:VimShell_Prompt."'"
execute 'syn match VimShellPrompt ' . "'".g:VimShell_SecondaryPrompt."'"
syn region   VimShellString   start=+'+ end=+'+ oneline
syn region   VimShellString   start=+"+ end=+"+ contains=VimShellQuoted oneline
syn region   VimShellString   start=+`+ end=+`+ oneline
syn region   VimShellError   start=+!!!+ end=+!!!+ contains=VimShellErrorHidden oneline
syn match   VimShellErrorHidden            '!!!' contained
syn match   VimShellComment   '#.*$' contained
syn match   VimShellConstants         '[+-]\=\<\d\+\>'
syn match   VimShellConstants         '[+-]\=\<0x\x\+\>'
syn match   VimShellConstants         '[+-]\=\<0\o\+\>'
syn match   VimShellConstants         '[+-]\=\d\+#[-+]\=\w\+\>'
syn match   VimShellConstants         '[+-]\=\d\+\.\d\+\([eE][+-]\?\d\+\)\?\>'
syn match   VimShellExe               '\(^\|[[:blank:]]\)[[:alnum:]_.][[:alnum:]_.-]\+\*[[:blank:]\n]'
syn match   VimShellSocket            '\(^\|[[:blank:]]\)[[:alnum:]_.][[:alnum:]_.-]\+=[[:blank:]\n]'
syn match   VimShellDotFiles          '\(^\|[[:blank:]]\)\.[[:alnum:]_.-]\+[[:blank:]\n]'
syn match   VimShellArguments         '[[:blank:]]-\=-[[:alnum:]-]\+=\=' contained
syn match   VimShellQuoted            '\\.' contained
syn match   VimShellSpecial           '[|<>;&;]' contained
syn match   VimShellSpecial           '!!\|!\d*' contained
syn match   VimShellVariable          '$\h\w*' contained
syn match   VimShellVariable          '$\%(\d\+\|[*@#?$!-]\)' contained
syn match   VimShellVariable          '$$\h\w*' contained
syn region   VimShellVariable  start=+${+ end=+}+ contained
syn region   VimShellVariable  start=+$(([[:blank:]]+ end=+[[:blank:]]))+ contained
syn keyword  vimshInternal        alias cd clear dirs ev exit h hide histdel history gcd iexe ls nop one popd pwd shell view vim vimsh  contained
syn keyword  vimshSpecial         command internal contained
if has('win32') || ('win64')
    syn match   VimShellArguments         '[[:blank:]]/[?:,_[:alnum:]]\+\ze\%(\s\|$\)' contained
    syn match   VimShellDirectory         '[/~]\=\f\+[/\\]\f*'
    syn match   VimShellLink              '\([[:alnum:]_.-]\+\.lnk\)'
else
    syn match   VimShellDirectory         '[/~]\=\f\+/\f*'
    syn match   VimShellLink              '\(^\|[[:blank:]]\)[[:alnum:]_.][[:alnum:]_.-]\+@'
endif

execute "syn region   VimShellExe start='" . g:VimShell_Prompt . "' end='\\f*[[:blank:]\\n]' contained contains=VimShellPrompt,VimShellSpecial,VimShellConstants,VimShellArguments,VimShellString,VimShellComment"
syn match VimShellExe '[|;][[:blank:]]*\f\+' contained contains=VimShellSpecial,VimShellArguments
execute "syn region   VimShellLine start='" . g:VimShell_Prompt ."' end='$' keepend contains=VimShellExe,VimShellDirectory,VimShellConstants,VimShellArguments, VimShellQuoted,VimShellString,VimShellVariable,VimShellSpecial,VimShellComment"

execute "syn region   VimShellExe start='" . g:VimShell_SecondaryPrompt . "' end='\\f*[[:blank:]\\n]' contained contains=VimShellPrompt,VimShellSpecial,VimShellConstants,VimShellArguments,VimShellString,VimShellComment"
execute "syn region   VimShellLine start='" . g:VimShell_SecondaryPrompt ."' end='$' keepend contains=VimShellExe,VimShellDirectory,VimShellConstants,VimShellArguments, VimShellQuoted,VimShellString,VimShellVariable,VimShellSpecial,VimShellComment"

if has('gui_running')
    hi VimShellPrompt  gui=UNDERLINE guifg=#80ffff guibg=NONE
else
    hi def link VimShellPrompt Identifier
endif

hi def link VimShellQuoted Special
hi def link VimShellString Constant
hi def link VimShellArguments Type
hi def link VimShellConstants Constant
hi def link VimShellSpecial PreProc
hi def link VimShellVariable Comment
hi def link VimShellComment Identifier
hi def link VimShellNormal Normal

hi def link VimShellExe Statement
hi def link VimShellDirectory Preproc
hi def link VimShellSocket Constant
hi def link VimShellLink Comment
hi def link VimShellDotFiles Identifier
hi def link VimShellError Error
hi def link VimShellErrorHidden Ignore

let b:current_syntax = "vimshell"
