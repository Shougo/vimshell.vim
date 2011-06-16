"=============================================================================
" FILE: syntax/int_earthquake.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 16 Jun 2011.
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

syn region  EarthquakeInputLine  start='^⚡ ' end='\n' oneline contains=EarthquakePrompt,EarthquakeString,EarthquakeCommand

syn match   EarthquakeURI         '\%(https\?\|ftp\)://[[:alnum:];/?:@&=+$,_.!~*''|()-]\+'
syn match   EarthquakeString      '.*' contained contains=EarthquakeReply,EarthquakeRemark
syn match   EarthquakeCommand     ':\w*' contained
syn match   EarthquakePrompt      '^\s*⚡ ' contained
syn match   EarthquakeReply       '@[[:alnum:]_-]\+:\?\|RT\s\|via\s\|QT\s\|(reply_to\s\[\$\h\w*\])'
syn match   EarthquakeName        '\s[[:alnum:]_-]\+:\s'
syn match   EarthquakeConstants   '[+-]\?\<\d\+\>'
syn match   EarthquakeConstants   '[+-]\?\<0x\x\+\>'
syn match   EarthquakeConstants   '[+-]\?\<0\o\+\>'
syn match   EarthquakeConstants   '[+-]\?\d\+#[-+]\=\w\+\>'
syn match   EarthquakeConstants   '[+-]\?\d\+\.\d\+\([eE][+-]\?\d\+\)\?\>'
syn match   EarthquakeRemark      '^\[\$\a\+\]'
syn match   EarthquakeRemark      '\$\a\+'
syn match   EarthquakeHashTag     '#\h\w*'
syn match   EarthquakeDate        '^(\d\+:\d\+:\d\+)'
syn match   EarthquakeMessage     '^updated => '
syn region  EarthquakeError       start='^\s*\[ERROR\] ' end='\n' oneline

syn keyword EarthquakeKeyword
      \ :delete :retweet :recent :search :eval :exit :reconnect
      \ :restart :thread :plugin_install :alias

augroup vimshell-int-earthquake
  autocmd!
  autocmd ColorScheme <buffer>    call s:color_scheme()
augroup END

function! s:color_scheme()"{{{
  if has('gui_running')
    hi EarthquakePrompt  gui=UNDERLINE guifg=#80ffff guibg=NONE
  else
    hi def link EarthquakePrompt Identifier
  endif
endfunction"}}}

call s:color_scheme()

hi def link EarthquakeConstants Constant
hi def link EarthquakeCommand Statement
hi def link EarthquakeKeyword Statement
if has('gui_running')
  hi EarthquakeURI gui=UNDERLINE guifg=#6699ff guibg=NONE
else
  hi def link EarthquakeURI Comment
endif
hi def link EarthquakeReply PreProc
hi def link EarthquakeName Type
hi def link EarthquakeMessage Constant
hi def link EarthquakeError Error
hi def link EarthquakeDate Constant
hi def link EarthquakeHashTag Comment
hi def link EarthquakeRemark Identifier

let b:current_syntax = 'int_earthquake'
