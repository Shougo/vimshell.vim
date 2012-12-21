"=============================================================================
" FILE: syntax/int-earthquake.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 20 Feb 2012.
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

scriptencoding utf-8

if version < 700
  syntax clear
elseif exists('b:current_syntax')
  finish
endif

syntax region  int_earthquakeInputLine  start='^⚡ ' end='\n' oneline
      \ contains=int_earthquakePrompt,int_earthquakeString,int_earthquakeCommand

syntax match   int_earthquakeURI
      \ '\%(https\?\|ftp\)://[[:alnum:];/?:@&=+$,_.!~*|()-]\+'
syntax match   int_earthquakeString
      \ '.*' contained contains=int_earthquakeReply,int_earthquakeRemark
syntax match   int_earthquakeCommand
      \ ':\w*' contained
syntax match   int_earthquakePrompt
      \ '^\s*⚡ ' contained
syntax match   int_earthquakeReply
      \ '@[[:alnum:]_-]\+:\?\|RT\s\|via\s\|QT\s\|(reply_to\s\[\$\h\w*\])'
syntax match   int_earthquakeName
      \ '\s[[:alnum:]_-]\+:\s'
syntax match   int_earthquakeConstants   '[+-]\?\<\d\+\>'
syntax match   int_earthquakeConstants   '[+-]\?\<0x\x\+\>'
syntax match   int_earthquakeConstants   '[+-]\?\<0\o\+\>'
syntax match   int_earthquakeConstants   '[+-]\?\d\+#[-+]\=\w\+\>'
syntax match   int_earthquakeConstants   '[+-]\?\d\+\.\d\+\([eE][+-]\?\d\+\)\?\>'
syntax match   int_earthquakeRemark      '\[\$\a\+\]'
syntax match   int_earthquakeRemark      '\$\a\+'
syntax match   int_earthquakeHashTag     '#\h\w*'
syntax match   int_earthquakeDate        '^(\d\+:\d\+:\d\+)'
syntax match   int_earthquakeMessage     '^:\?\h\w* \|^\[\h\w*\] '
syntax region  int_earthquakeError       start='^\s*\[ERROR\] ' end='\n' oneline
syntax match   int_earthquakeCommandOutput '^\s\ze\['

syntax keyword int_earthquakeKeyword
      \ :exit :help :restart :eval :aa :update :reply :status
      \ :delete :mentions :follow :unfollow :recent :user :search :filter
      \ :favorite :unfavorite :retweet :retweeted_by_me :retweeted_to_me :retweets_of_me
      \ :block :unblock :report_spam :messages :sent_messages :message
      \ :reconnect :thread :update_profile_image :open :browse
      \ :sh :plugin_install :edit_config :alias :reauthorize

augroup vimshell-int_earthquake
  autocmd!
  autocmd ColorScheme <buffer>    call s:color_scheme()
augroup END

function! s:color_scheme() "{{{
  if has('gui_running')
    highlight int_earthquakePrompt  gui=UNDERLINE guifg=#80ffff guibg=NONE
  else
    highlight def link int_earthquakePrompt Identifier
  endif
endfunction"}}}

call s:color_scheme()

highlight def link int_earthquakeConstants Constant
highlight def link int_earthquakeCommand Statement
highlight def link int_earthquakeKeyword Statement
if has('gui_running')
  highlight int_earthquakeURI gui=UNDERLINE guifg=#6699ff guibg=NONE
else
  highlight def link int_earthquakeURI Comment
endif

highlight def link int_earthquakeReply PreProc
highlight def link int_earthquakeName Type
highlight def link int_earthquakeMessage Constant
highlight def link int_earthquakeError Error
highlight def link int_earthquakeDate Constant
highlight def link int_earthquakeHashTag Comment
highlight def link int_earthquakeRemark Identifier
highlight def link int_earthquakeCommandOutput Underlined

let b:current_syntax = 'int-earthquake'
