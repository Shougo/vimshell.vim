"=============================================================================
" FILE: syntax/vimshell.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 21 Jan 2013.
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

syntax match   vimshellUserPrompt
      \ '^\[%\] .*$' contains=vimshellUserPromptHidden
syntax region   vimshellString
      \ start=+'+ end=+'+ oneline contained
syntax region   vimshellString
      \ start=+"+ end=+"+ contains=vimshellQuoted oneline contained
syntax region   vimshellString
      \ start=+`+ end=+`+ oneline contained
syntax match   vimshellString
      \ '[''"`]$' contained contained
syntax match   vimshellError
        \ '\%([^!]\|^\)\zs!!!.\+!!!\ze\%([^!]\|$\)' contains=vimshellErrorHidden
syntax match   vimshellComment
      \ '#.*$' contained
syntax match   vimshellConstants
      \ '[+-]\=\<\d\+\>'
syntax match   vimshellConstants
      \ '[+-]\=\<0x\x\+\>'
syntax match   vimshellConstants
      \ '[+-]\=\<0\o\+\>'
syntax match   vimshellConstants
      \ '[+-]\=\d\+#[-+]\=\w\+\>'
syntax match   vimshellConstants
      \ '[+-]\=\d\+\.\d\+\([eE][+-]\?\d\+\)\?\>'
syntax match   vimshellExe
      \ '\%(^\|\s\)[[:alnum:]_.][[:alnum:]_.-]\+\*[[:blank:]\n]'
syntax match   vimshellSocket
      \ '\%(^\|\s\)[[:alnum:]_.][[:alnum:]_.-]\+=[[:blank:]\n]'
syntax match   vimshellDotFiles
      \ '\%(^\|\s\)\.[[:alnum:]_.-]\+[[:blank:]\n]'
syntax match   vimshellArguments
      \ '\s-\=-[[:alnum:]-]\+=\=' contained
syntax match   vimshellQuoted
      \ '\\.' contained
syntax match   vimshellSpecial
      \ '[|<>;&;]' contained
syntax match   vimshellVariable
      \ '$\h\w*' contained
syntax match   vimshellVariable
      \ '$$\h\w*' contained
syntax region   vimshellVariable  start=+${+ end=+}+ contained
if vimshell#util#is_windows()
  syntax match   vimshellArguments
        \ '\s/[?:,_[:alnum:]]\+\ze\%(\s\|$\)' contained
  syntax match   vimshellDirectory
        \ '\%(\f\s\?\)\+[/\\]\ze\%(\s\|$\)'
  syntax match   vimshellLink
        \ '\([[:alnum:]_.-]\+\.lnk\)'
else
  syntax match   vimshellDirectory
        \ '\%(\f\s\?\)\+/\ze\%(\s\|$\)'
  syntax match   vimshellLink
        \ '\(^\|\s\)[[:alnum:]_.][[:alnum:]_.-]\+@'
endif

if has('conceal')
  " Supported conceal features.
  syntax match   vimshellErrorHidden
        \ '\%([^!]\|^\)\zs!!!\ze\%([^!]\|$\)' contained conceal
  syntax match   vimshellUserPromptHidden
        \ '^\[%\] ' contained conceal
else
  syntax match   vimshellErrorHidden
        \ '\%([^!]\|^\)\zs!!!\ze\%([^!]\|$\)' contained
  syntax match   vimshellUserPromptHidden
        \ '^\[%\] ' contained
  highlight default link vimshellErrorHidden Ignore
  highlight default link vimshellUserPromptHidden Ignore
endif

syntax match vimshellExe '[|;]\s*\f\+'
      \ contained contains=vimshellSpecial,vimshellArguments

highlight default link vimshellPrompt Identifier
highlight default link vimshellUserPrompt Special

highlight default link vimshellQuoted Special
highlight default link vimshellString String
highlight default link vimshellArguments Type
highlight default link vimshellConstants Constant
highlight default link vimshellSpecial PreProc
highlight default link vimshellVariable Comment
highlight default link vimshellComment Identifier
highlight default link vimshellNormal Normal

highlight default link vimshellExe Statement
highlight default link vimshellDirectory Preproc
highlight default link vimshellSocket Constant
highlight default link vimshellLink Comment
highlight default link vimshellDotFiles Identifier
highlight default link vimshellError Error

call vimshell#set_highlight()

let b:current_syntax = 'vimshell'
