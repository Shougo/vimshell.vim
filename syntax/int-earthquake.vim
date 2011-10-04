"=============================================================================
" FILE: syntax/int_earthquake.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 04 Oct 2011.
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

syntax region  EarthquakeInputLine  start='^⚡ ' end='\n' oneline contains=EarthquakePrompt,EarthquakeString,EarthquakeCommand

syntax match   EarthquakeURI         '\%(https\?\|ftp\)://[[:alnum:];/?:@&=+$,_.!~*''|()-]\+'
syntax match   EarthquakeString      '.*' contained contains=EarthquakeReply,EarthquakeRemark
syntax match   EarthquakeCommand     ':\w*' contained
syntax match   EarthquakePrompt      '^\s*⚡ ' contained
syntax match   EarthquakeReply       '@[[:alnum:]_-]\+:\?\|RT\s\|via\s\|QT\s\|(reply_to\s\[\$\h\w*\])'
syntax match   EarthquakeName        '\s[[:alnum:]_-]\+:\s'
syntax match   EarthquakeConstants   '[+-]\?\<\d\+\>'
syntax match   EarthquakeConstants   '[+-]\?\<0x\x\+\>'
syntax match   EarthquakeConstants   '[+-]\?\<0\o\+\>'
syntax match   EarthquakeConstants   '[+-]\?\d\+#[-+]\=\w\+\>'
syntax match   EarthquakeConstants   '[+-]\?\d\+\.\d\+\([eE][+-]\?\d\+\)\?\>'
syntax match   EarthquakeRemark      '^\[\$\a\+\]'
syntax match   EarthquakeRemark      '\$\a\+'
syntax match   EarthquakeHashTag     '#\h\w*'
syntax match   EarthquakeDate        '^(\d\+:\d\+:\d\+)'
syntax match   EarthquakeMessage     '^:\?\h\w* \|^\[\h\w*\] '
syntax region  EarthquakeError       start='^\s*\[ERROR\] ' end='\n' oneline

syntax keyword EarthquakeKeyword
      \ :exit :help :restart :eval :update :reply :status
      \ :delete :mentions :follow :unfollow :recent :user :search
      \ :favorite :unfavorite :retweet :retweeted_by_me :retweeted_to_me :retweeted_of_me
      \ :block :unblock :report_spam :messages :sent_messages
      \ :reconnect :thread :update_profile_image :browse
      \ :sh :plugin_install :edit_config :alias :reauthorize

augroup vimshell-int-earthquake
  autocmd!
  autocmd ColorScheme <buffer>    call s:color_scheme()
augroup END

function! s:color_scheme()"{{{
  if has('gui_running')
    highlight EarthquakePrompt  gui=UNDERLINE guifg=#80ffff guibg=NONE
  else
    highlight def link EarthquakePrompt Identifier
  endif
endfunction"}}}

call s:color_scheme()

highlight def link EarthquakeConstants Constant
highlight def link EarthquakeCommand Statement
highlight def link EarthquakeKeyword Statement
if has('gui_running')
  highlight EarthquakeURI gui=UNDERLINE guifg=#6699ff guibg=NONE
else
  highlight def link EarthquakeURI Comment
endif
highlight def link EarthquakeReply PreProc
highlight def link EarthquakeName Type
highlight def link EarthquakeMessage Constant
highlight def link EarthquakeError Error
highlight def link EarthquakeDate Constant
highlight def link EarthquakeHashTag Comment
highlight def link EarthquakeRemark Identifier

let b:current_syntax = 'int_earthquake'
