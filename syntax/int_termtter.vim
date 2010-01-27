"=============================================================================
" FILE: syntax/int_termtter.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 27 Jun 2010
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
" Version: 1.1, for Vim 7.0
"-----------------------------------------------------------------------------
" ChangeLog: "{{{
"   1.1:
"     - Improved reply.
"     - Improved URI.
"
"   1.0:
"     - Initial version.
""}}}
"=============================================================================

if version < 700
  syntax clear
elseif exists('b:current_syntax')
  finish
endif

syn region   TermtterInputLine  start='^> ' end='\n' contains=TermtterPrompt,TermtterCommand,TermtterString
syn keyword TermtterKeyword     restore_user redo shows replies exit pause direct retweet lists hashtag add search fib remove_alias switch resume settings hashtag clear raw_update limit vi_editing_mode reply hashtag list follow show list exec emacs_editing_mode favorite profile delete eval leave alias reload plug help followers update
syn match   TermtterURI         '\%(https\?\|ftp\)://[[:alnum:];/?:@&=+$,_.!~*''|()-]\+'
syn match   TermtterString      '.*' contained contains=TermtterReply
syn match   TermtterCommand     '[[:alnum:]_][[:alnum:]_-]*' contained
syn match   TermtterPrompt      '^> ' contained
syn match   TermtterReply       '@[[:alnum:]_+-]\+:\?\|RT\s\|via\s\|QT\s\|(reply_to\s\[\$\h\w*\])'
syn match   TermtterName       '\s[[:alnum:]_+-]\+:\s'
syn match   TermtterConstants   '[+-]\?\<\d\+\>'
syn match   TermtterConstants   '[+-]\?\<0x\x\+\>'
syn match   TermtterConstants   '[+-]\?\<0\o\+\>'
syn match   TermtterConstants   '[+-]\?\d\+#[-+]\=\w\+\>'
syn match   TermtterConstants   '[+-]\?\d\+\.\d\+\([eE][+-]\?\d\+\)\?\>'
syn match   TermtterWaiting     '^\.\.\.$'
syn match   TermtterMessage     '^updated => '

if has('gui_running')
    hi TermtterPrompt  gui=UNDERLINE guifg=#80ffff guibg=NONE
    hi TermtterWaiting  gui=UNDERLINE guifg=#80ffff guibg=NONE
else
    hi def link TermtterPrompt Identifier
    hi def link TermtterWaiting Identifier
endif

hi def link TermtterString Comment
hi def link TermtterConstants Constant
hi def link TermtterCommand Statement
if has('gui_running')
    hi TermtterURI gui=UNDERLINE guifg=#6699ff guibg=NONE
else
    hi def link TermtterURI Preproc
endif
hi def link TermtterReply Special
hi def link TermtterName Type
hi def link TermtterMessage Constant

let b:current_syntax = 'int_termtter'
