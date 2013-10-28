"=============================================================================
" FILE: syntax/int-termtter.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 17 Sep 2013.
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

syntax region   int_termtterInputLine  start='^\s*> ' end='\n' oneline
      \ contains=int_termtterPrompt,int_termtterCommand,int_termtterString

syntax match   int_termtterURI         '\%(https\?\|ftp\)://[[:alnum:];/?:@&=+$,_.!~*''|()-]\+'
syntax match   int_termtterString      '.*' contained contains=int_termtterReply,int_termtterRemark
syntax match   int_termtterCommand     '\w\+' contained
syntax match   int_termtterPrompt      '^\s*> ' contained
syntax match   int_termtterReply       '@[[:alnum:]_-]\+:\?\|RT\s\|via\s\|QT\s\|(reply_to\s\[\$\h\w*\])'
syntax match   int_termtterName        '\s[[:alnum:]_-]\+:\s'
syntax match   int_termtterConstants   '[+-]\?\<\d\+\>'
syntax match   int_termtterConstants   '[+-]\?\<0x\x\+\>'
syntax match   int_termtterConstants   '[+-]\?\<0\o\+\>'
syntax match   int_termtterConstants   '[+-]\?\d\+#[-+]\=\w\+\>'
syntax match   int_termtterConstants   '[+-]\?\d\+\.\d\+\([eE][+-]\?\d\+\)\?\>'
syntax match   int_termtterRemark      '\[\$\a\+\]'
syntax match   int_termtterRemark      '\$\a\+'
syntax match   int_termtterHashTag     '#\h\w*'
syntax match   int_termtterDate        '^(\d\+:\d\+:\d\+)'
syntax match   int_termtterMessage     '^updated => '
syntax region  int_termtterError       start='^\s*\[ERROR\] ' end='\n' oneline

syntax keyword int_termtterKeyword
      \ add alias block cache cache clear create d del delete direct edit emacs_editing_mode eval exec
      \ exit fav favlist favorite favorites fib flush follow followers friends h hashtag hashtag hashtag help keyword
      \ l leave limit list list lists lm load pause plug profile quit r raw_update redo reload
      \ remove_alias re remove replies reply restore_user resume retweet retweeted_to_me retweeted_by_me retweets retweets_of_me
      \ rt s save search sent_list set settings show shows stats status switch u unblock update user vi_editing_mode

augroup vimshell-int-termtter
  autocmd! * <buffer>
  autocmd ColorScheme <buffer>    call s:color_scheme()
augroup END

function! s:color_scheme() "{{{
  if has('gui_running')
    highlight int_termtterPrompt  gui=UNDERLINE guifg=#80ffff guibg=NONE
  else
    highlight default link int_termtterPrompt Identifier
  endif
endfunction"}}}

call s:color_scheme()

highlight default link int_termtterConstants Constant
highlight default link int_termtterCommand Statement
highlight default link int_termtterKeyword Statement
if has('gui_running')
  highlight int_termtterURI gui=UNDERLINE guifg=#6699ff guibg=NONE
else
  highlight default link int_termtterURI Comment
endif
highlight default link int_termtterReply PreProc
highlight default link int_termtterName Type
highlight default link int_termtterMessage Constant
highlight default link int_termtterError Error
highlight default link int_termtterDate Constant
highlight default link int_termtterHashTag Comment
highlight default link int_termtterRemark Identifier

let b:current_syntax = 'int-termtter'
