"=============================================================================
" FILE: history.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 04 Jul 2010
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

function! vimshell#history#append(command)"{{{
  " Reduce blanks.
  let l:command = substitute(a:command, '\s\+', ' ', 'g')
  
  let l:program = matchstr(l:command, vimshell#get_program_pattern())
  if l:program != '' && has_key(g:vimshell_no_save_history_commands, l:program)
    " No history command.
    return
  endif
  
  " Reload history.
  let l:history_path = g:vimshell_temporary_directory . '/command-history'
  let g:vimshell#hist_buffer = readfile(l:history_path)
  
  " Filtering.
  call insert(filter(g:vimshell#hist_buffer, 'v:val !=# ' . string(a:command)), l:command)

  " Trunk.
  let g:vimshell#hist_buffer = g:vimshell#hist_buffer[: g:vimshell_max_command_history-1]

  " Save history file.
  let l:temp_name = tempname()
  call writefile(g:vimshell#hist_buffer, l:temp_name)
  call rename(l:temp_name, l:history_path)
endfunction"}}}
function! vimshell#history#read()"{{{
  let l:history_path = g:vimshell_temporary_directory . '/command-history'
  if !filereadable(l:history_path)
    " Create file.
    call writefile([], l:history_path)
  endif

  return readfile(l:history_path)
endfunction"}}}
function! vimshell#history#external_read(filename)"{{{
  if a:filename == '' || !filereadable(a:filename)
    return []
  endif
  
  let l:list = []
  for l:line in readfile(a:filename)
    if l:line =~ '^:'
      " Convert zsh extend history.
      let l:line = l:line[stridx(l:line, ';')+1 :]
    endif

    call add(l:list, l:line)
  endfor

  return l:list
endfunction"}}}

function! vimshell#history#interactive_append(command)"{{{
  if has_key(g:vimshell_interactive_no_save_history_commands, &filetype[4:])
        \ && g:vimshell_interactive_no_save_history_commands[&filetype[4:]]
    " No history command.
    return
  endif
  
  " Reload history.
  let l:history_dir = g:vimshell_temporary_directory . '/int-history'
  if !isdirectory(fnamemodify(l:history_dir, ':p'))
    call mkdir(fnamemodify(l:history_dir, ':p'), 'p')
  endif
  let l:history_path = l:history_dir . '/'.&filetype
  let b:interactive.command_history = readfile(l:history_path)

  " Reduce blanks.
  let l:command = substitute(a:command, '\s\+', ' ', 'g')
  " Filtering.
  call insert(filter(b:interactive.command_history, 'v:val !=# '.string(substitute(l:command, "'", "''", 'g'))), l:command)

  " Trunk.
  let b:interactive.command_history = b:interactive.command_history[: g:vimshell_max_command_history-1]

  " Save history file.
  let l:temp_name = tempname()
  call writefile(b:interactive.command_history, l:temp_name)
  call rename(l:temp_name, l:history_path)
endfunction"}}}
function! vimshell#history#interactive_read()"{{{
  let l:history_dir = g:vimshell_temporary_directory . '/int-history'
  if !isdirectory(fnamemodify(l:history_dir, ':p'))
    call mkdir(fnamemodify(l:history_dir, ':p'), 'p')
  endif

  let l:path = l:history_dir . '/'.&filetype
  if filereadable(l:path)
    return readfile(l:path)
  else
    return []
  endif
endfunction"}}}

" vim: foldmethod=marker
