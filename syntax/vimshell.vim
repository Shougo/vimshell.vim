"=============================================================================
" FILE: syntax/vimshell.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 01 Jan 2012.
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

execute 'syntax match VimShellPrompt' string('^' . vimshell#escape_match(vimshell#get_prompt()))
execute 'syntax match VimShellPrompt' string('^' . vimshell#escape_match(vimshell#get_secondary_prompt()))
syntax match   VimShellUserPrompt   '^\[%\] .*$' contains=VimShellUserPromptHidden
syntax region   VimShellString   start=+'+ end=+'+ oneline
syntax region   VimShellString   start=+"+ end=+"+ contains=VimShellQuoted oneline
syntax region   VimShellString   start=+`+ end=+`+ oneline
syntax match   VimShellString   '[''"`]$' contained
syntax region   VimShellError   start=+!!!+ end=+!!!+ contains=VimShellErrorHidden oneline
syntax match   VimShellComment   '#.*$' contained
syntax match   VimShellConstants         '[+-]\=\<\d\+\>'
syntax match   VimShellConstants         '[+-]\=\<0x\x\+\>'
syntax match   VimShellConstants         '[+-]\=\<0\o\+\>'
syntax match   VimShellConstants         '[+-]\=\d\+#[-+]\=\w\+\>'
syntax match   VimShellConstants         '[+-]\=\d\+\.\d\+\([eE][+-]\?\d\+\)\?\>'
syntax match   VimShellExe               '\%(^\|\s\)[[:alnum:]_.][[:alnum:]_.-]\+\*[[:blank:]\n]'
syntax match   VimShellSocket            '\%(^\|\s\)[[:alnum:]_.][[:alnum:]_.-]\+=[[:blank:]\n]'
syntax match   VimShellDotFiles          '\%(^\|\s\)\.[[:alnum:]_.-]\+[[:blank:]\n]'
syntax match   VimShellArguments         '\s-\=-[[:alnum:]-]\+=\=' contained
syntax match   VimShellQuoted            '\\.' contained
syntax match   VimShellSpecial           '[|<>;&;]' contained
syntax match   VimShellVariable          '$\h\w*' contained
syntax match   VimShellVariable          '$$\h\w*' contained
syntax region   VimShellVariable  start=+${+ end=+}+ contained
if vimshell#iswin()
  syntax match   VimShellArguments         '\s/[?:,_[:alnum:]]\+\ze\%(\s\|$\)' contained
  syntax match   VimShellDirectory         '\%(\f\s\?\)\+[/\\]\ze\%(\s\|$\)'
  syntax match   VimShellLink              '\([[:alnum:]_.-]\+\.lnk\)'
else
  syntax match   VimShellDirectory         '\%(\f\s\?\)\+/\ze\%(\s\|$\)'
  syntax match   VimShellLink              '\(^\|\s\)[[:alnum:]_.][[:alnum:]_.-]\+@'
endif
syntax region   VimShellHistory  start=+^\s*\d\+:\s[^[:space:]]+ end=+.*+ oneline
syntax region   VimShellGrep  start=+^[^!]\f\+:+ end=+.*+ oneline

if has('conceal')
  " Supported conceal features.
  syntax match   VimShellErrorHidden            '!!!' contained conceal
  syntax match   VimShellUserPromptHidden       '^\[%\] ' contained conceal
else
  syntax match   VimShellErrorHidden            '!!!' contained
  syntax match   VimShellUserPromptHidden       '^\[%\] ' contained
endif

execute "syntax region   VimShellExe start=".string('^'.vimshell#escape_match(vimshell#get_prompt())) "end='[^[:blank:]]\\+\\zs[[:blank:]\\n]' contained contains=VimShellPrompt,VimShellSpecial,VimShellConstants,VimShellArguments,VimShellString,VimShellComment"
syntax match VimShellExe '[|;]\s*\f\+' contained contains=VimShellSpecial,VimShellArguments
execute "syntax region   VimShellLine start=".string('^'.vimshell#escape_match(vimshell#get_prompt())) "end='$' keepend contains=VimShellExe,VimShellDirectory,VimShellConstants,VimShellArguments, VimShellQuoted,VimShellString,VimShellVariable,VimShellSpecial,VimShellComment"

execute "syntax region   VimShellExe start=".string('^'.vimshell#escape_match(vimshell#get_secondary_prompt())) "end='[^[:blank:]]\\+\\zs[[:blank:]\\n]' contained contains=VimShellPrompt,VimShellSpecial,VimShellConstants,VimShellArguments,VimShellString,VimShellComment"
execute "syntax region   VimShellLine start=".string('^'.vimshell#escape_match(vimshell#get_secondary_prompt())) "end='$' keepend contains=VimShellExe,VimShellDirectory,VimShellConstants,VimShellArguments, VimShellQuoted,VimShellString,VimShellVariable,VimShellSpecial,VimShellComment"

if has('gui_running')
  highlight VimShellPrompt  gui=UNDERLINE guifg=#80ffff guibg=NONE
else
  highlight default link VimShellPrompt Identifier
endif

highlight default link VimShellUserPrompt Special

highlight default link VimShellQuoted Special
highlight default link VimShellString Constant
highlight default link VimShellArguments Type
highlight default link VimShellConstants Constant
highlight default link VimShellSpecial PreProc
highlight default link VimShellVariable Comment
highlight default link VimShellComment Identifier
highlight default link VimShellHistory Comment
highlight default link VimShellGrep Comment
highlight default link VimShellNormal Normal

highlight default link VimShellExe Statement
highlight default link VimShellDirectory Preproc
highlight default link VimShellSocket Constant
highlight default link VimShellLink Comment
highlight default link VimShellDotFiles Identifier
highlight default link VimShellError Error
highlight default link VimShellErrorHidden Ignore
highlight default link VimShellUserPromptHidden Ignore

let b:current_syntax = 'vimshell'
