"=============================================================================
" FILE: syntax/int_termtter.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 14 Jun 2011.
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

syn region   TermtterInputLine  start='^\s*> ' end='\n' oneline contains=TermtterPrompt,TermtterCommand,TermtterString

syn match   TermtterURI         '\%(https\?\|ftp\)://[[:alnum:];/?:@&=+$,_.!~*''|()-]\+'
syn match   TermtterString      '.*' contained contains=TermtterReply,TermtterRemark
syn match   TermtterCommand     '\w\+' contained
syn match   TermtterPrompt      '^\s*> ' contained
syn match   TermtterReply       '@[[:alnum:]_-]\+:\?\|RT\s\|via\s\|QT\s\|(reply_to\s\[\$\h\w*\])'
syn match   TermtterName        '\s[[:alnum:]_-]\+:\s'
syn match   TermtterConstants   '[+-]\?\<\d\+\>'
syn match   TermtterConstants   '[+-]\?\<0x\x\+\>'
syn match   TermtterConstants   '[+-]\?\<0\o\+\>'
syn match   TermtterConstants   '[+-]\?\d\+#[-+]\=\w\+\>'
syn match   TermtterConstants   '[+-]\?\d\+\.\d\+\([eE][+-]\?\d\+\)\?\>'
syn match   TermtterRemark      '\[\$\a\+\]'
syn match   TermtterRemark      '\$\a\+'
syn match   TermtterHashTag     '#\h\w*'
syn match   TermtterDate        '^(\d\+:\d\+:\d\+)'
syn match   TermtterMessage     '^updated => '
syn region  TermtterError       start='^\s*\[ERROR\] ' end='\n' oneline

syn keyword TermtterKeyword     
      \ add alias block cache cache clear create d del delete direct edit emacs_editing_mode eval exec
      \ exit fav favlist favorite favorites fib flush follow followers friends h hashtag hashtag hashtag help keyword
      \ l leave limit list list lists lm load pause plug profile quit r raw_update redo reload
      \ remove_alias re remove replies reply restore_user resume retweet retweeted_to_me retweeted_by_me retweets retweets_of_me
      \ rt s save search sent_list set settings show shows stats status switch u unblock update user vi_editing_mode

augroup vimshell-int-termtter
  autocmd!
  autocmd ColorScheme <buffer>    call s:color_scheme()
augroup END

function! s:color_scheme()"{{{
  if has('gui_running')
    hi TermtterPrompt  gui=UNDERLINE guifg=#80ffff guibg=NONE
  else
    hi def link TermtterPrompt Identifier
  endif
endfunction"}}}

call s:color_scheme()

hi def link TermtterConstants Constant
hi def link TermtterCommand Statement
hi def link TermtterKeyword Statement
if has('gui_running')
  hi TermtterURI gui=UNDERLINE guifg=#6699ff guibg=NONE
else
  hi def link TermtterURI Comment
endif
hi def link TermtterReply PreProc
hi def link TermtterName Type
hi def link TermtterMessage Constant
hi def link TermtterError Error
hi def link TermtterDate Constant
hi def link TermtterHashTag Comment
hi def link TermtterRemark Identifier

let b:current_syntax = 'int_termtter'
