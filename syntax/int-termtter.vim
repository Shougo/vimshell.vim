"=============================================================================
" FILE: syntax/int_termtter.vim
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
elseif exists('b:current_syntax')
  finish
endif

syntax region   TermtterInputLine  start='^\s*> ' end='\n' oneline
      \ contains=TermtterPrompt,TermtterCommand,TermtterString

syntax match   TermtterURI         '\%(https\?\|ftp\)://[[:alnum:];/?:@&=+$,_.!~*''|()-]\+'
syntax match   TermtterString      '.*' contained contains=TermtterReply,TermtterRemark
syntax match   TermtterCommand     '\w\+' contained
syntax match   TermtterPrompt      '^\s*> ' contained
syntax match   TermtterReply       '@[[:alnum:]_-]\+:\?\|RT\s\|via\s\|QT\s\|(reply_to\s\[\$\h\w*\])'
syntax match   TermtterName        '\s[[:alnum:]_-]\+:\s'
syntax match   TermtterConstants   '[+-]\?\<\d\+\>'
syntax match   TermtterConstants   '[+-]\?\<0x\x\+\>'
syntax match   TermtterConstants   '[+-]\?\<0\o\+\>'
syntax match   TermtterConstants   '[+-]\?\d\+#[-+]\=\w\+\>'
syntax match   TermtterConstants   '[+-]\?\d\+\.\d\+\([eE][+-]\?\d\+\)\?\>'
syntax match   TermtterRemark      '\[\$\a\+\]'
syntax match   TermtterRemark      '\$\a\+'
syntax match   TermtterHashTag     '#\h\w*'
syntax match   TermtterDate        '^(\d\+:\d\+:\d\+)'
syntax match   TermtterMessage     '^updated => '
syntax region  TermtterError       start='^\s*\[ERROR\] ' end='\n' oneline

syntax keyword TermtterKeyword
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
    highlight TermtterPrompt  gui=UNDERLINE guifg=#80ffff guibg=NONE
  else
    highlight default link TermtterPrompt Identifier
  endif
endfunction"}}}

call s:color_scheme()

highlight default link TermtterConstants Constant
highlight default link TermtterCommand Statement
highlight default link TermtterKeyword Statement
if has('gui_running')
  highlight TermtterURI gui=UNDERLINE guifg=#6699ff guibg=NONE
else
  highlight default link TermtterURI Comment
endif
highlight default link TermtterReply PreProc
highlight default link TermtterName Type
highlight default link TermtterMessage Constant
highlight default link TermtterError Error
highlight default link TermtterDate Constant
highlight default link TermtterHashTag Comment
highlight default link TermtterRemark Identifier

let b:current_syntax = 'int_termtter'
