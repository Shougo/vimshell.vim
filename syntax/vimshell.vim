"=============================================================================
" FILE: syntax/vimshell.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 26 Jul 2010
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
elseif exists("b:current_syntax")
  finish
endif

execute 'syn match VimShellPrompt' string('^' . vimshell#escape_match(vimshell#get_prompt()))
execute 'syn match VimShellPrompt' string('^' . vimshell#escape_match(vimshell#get_secondary_prompt()))
syn match   VimShellUserPrompt   '^\[%\] .*$' contains=VimShellUserPromptHidden
syn region   VimShellString   start=+'+ end=+'+ oneline
syn region   VimShellString   start=+"+ end=+"+ contains=VimShellQuoted oneline
syn region   VimShellString   start=+`+ end=+`+ oneline
syn match   VimShellString   '[''"`]$' contained
syn region   VimShellError   start=+!!!+ end=+!!!+ contains=VimShellErrorHidden oneline
syn match   VimShellComment   '#.*$' contained
syn match   VimShellConstants         '[+-]\=\<\d\+\>'
syn match   VimShellConstants         '[+-]\=\<0x\x\+\>'
syn match   VimShellConstants         '[+-]\=\<0\o\+\>'
syn match   VimShellConstants         '[+-]\=\d\+#[-+]\=\w\+\>'
syn match   VimShellConstants         '[+-]\=\d\+\.\d\+\([eE][+-]\?\d\+\)\?\>'
syn match   VimShellExe               '\%(^\|\s\)[[:alnum:]_.][[:alnum:]_.-]\+\*[[:blank:]\n]'
syn match   VimShellSocket            '\%(^\|\s\)[[:alnum:]_.][[:alnum:]_.-]\+=[[:blank:]\n]'
syn match   VimShellDotFiles          '\%(^\|\s\)\.[[:alnum:]_.-]\+[[:blank:]\n]'
syn match   VimShellArguments         '\s-\=-[[:alnum:]-]\+=\=' contained
syn match   VimShellQuoted            '\\.' contained
syn match   VimShellSpecial           '[|<>;&;]' contained
syn match   VimShellVariable          '$\h\w*' contained
syn match   VimShellVariable          '$$\h\w*' contained
syn region   VimShellVariable  start=+${+ end=+}+ contained
if vimshell#iswin()
    syn match   VimShellArguments         '\s/[?:,_[:alnum:]]\+\ze\%(\s\|$\)' contained
    syn match   VimShellDirectory         '\%(\f\s\?\)\+[/\\]\ze\%(\s\|$\)'
    syn match   VimShellLink              '\([[:alnum:]_.-]\+\.lnk\)'
else
    syn match   VimShellDirectory         '\%(\f\s\?\)\+/\ze\%(\s\|$\)'
    syn match   VimShellLink              '\(^\|\s\)[[:alnum:]_.][[:alnum:]_.-]\+@'
endif
syn region   VimShellHistory  start=+^\s*\d\+:\s[^[:space:]]+ end=+.*+ oneline

if has('conceal')
  " Supported conceal features.
  syn match   VimShellErrorHidden            '!!!' contained conceal
  syn match   VimShellUserPromptHidden       '\[%\] ' contained conceal
else
  syn match   VimShellErrorHidden            '!!!' contained
  syn match   VimShellUserPromptHidden       '\[%\] ' contained
endif

execute "syn region   VimShellExe start=".string('^'.vimshell#escape_match(vimshell#get_prompt())) "end='[^[:blank:]]\\+\\zs[[:blank:]\\n]' contained contains=VimShellPrompt,VimShellSpecial,VimShellConstants,VimShellArguments,VimShellString,VimShellComment"
syn match VimShellExe '[|;]\s*\f\+' contained contains=VimShellSpecial,VimShellArguments
execute "syn region   VimShellLine start=".string('^'.vimshell#escape_match(vimshell#get_prompt())) "end='$' keepend contains=VimShellExe,VimShellDirectory,VimShellConstants,VimShellArguments, VimShellQuoted,VimShellString,VimShellVariable,VimShellSpecial,VimShellComment"

execute "syn region   VimShellExe start=".string('^'.vimshell#escape_match(vimshell#get_secondary_prompt())) "end='[^[:blank:]]\\+\\zs[[:blank:]\\n]' contained contains=VimShellPrompt,VimShellSpecial,VimShellConstants,VimShellArguments,VimShellString,VimShellComment"
execute "syn region   VimShellLine start=".string('^'.vimshell#escape_match(vimshell#get_secondary_prompt())) "end='$' keepend contains=VimShellExe,VimShellDirectory,VimShellConstants,VimShellArguments, VimShellQuoted,VimShellString,VimShellVariable,VimShellSpecial,VimShellComment"

if has('gui_running')
    hi VimShellPrompt  gui=UNDERLINE guifg=#80ffff guibg=NONE
else
    hi def link VimShellPrompt Identifier
endif

hi def link VimShellUserPrompt Special

hi def link VimShellQuoted Special
hi def link VimShellString Constant
hi def link VimShellArguments Type
hi def link VimShellConstants Constant
hi def link VimShellSpecial PreProc
hi def link VimShellVariable Comment
hi def link VimShellComment Identifier
hi def link VimShellHistory Comment
hi def link VimShellNormal Normal

hi def link VimShellExe Statement
hi def link VimShellDirectory Preproc
hi def link VimShellSocket Constant
hi def link VimShellLink Comment
hi def link VimShellDotFiles Identifier
hi def link VimShellError Error
hi def link VimShellErrorHidden Ignore
hi def link VimShellUserPromptHidden Ignore

let b:current_syntax = 'vimshell'
