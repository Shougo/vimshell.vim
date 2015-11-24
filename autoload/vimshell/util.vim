"=============================================================================
" FILE: util.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
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

let s:V = vital#of('vimshell')

function! vimshell#util#get_vital() "{{{
  return s:V
endfunction"}}}
function! s:get_prelude() "{{{
  if !exists('s:Prelude')
    let s:Prelude = vimshell#util#get_vital().import('Prelude')
  endif
  return s:Prelude
endfunction"}}}
function! s:get_list() "{{{
  if !exists('s:List')
    let s:List = vimshell#util#get_vital().import('Data.List')
  endif
  return s:List
endfunction"}}}
function! s:get_process() "{{{
  if !exists('s:Process')
    let s:Process = vimshell#util#get_vital().import('Process')
  endif
  return s:Process
endfunction"}}}

function! vimshell#util#truncate_smart(...) "{{{
  return call(s:get_prelude().truncate_smart, a:000)
endfunction"}}}

function! vimshell#util#truncate(...) "{{{
  return call(s:get_prelude().truncate, a:000)
endfunction"}}}

function! vimshell#util#strchars(string) "{{{
  return len(substitute(a:string, '.', 'x', 'g'))
endfunction"}}}

function! vimshell#util#strwidthpart(...) "{{{
  return call(s:get_prelude().strwidthpart, a:000)
endfunction"}}}
function! vimshell#util#strwidthpart_reverse(...) "{{{
  return call(s:get_prelude().strwidthpart_reverse, a:000)
endfunction"}}}

" Use builtin function.
function! vimshell#util#strwidthpart_len(str, width) "{{{
  let ret = a:str
  let width = strwidth(a:str)
  while width > a:width
    let char = matchstr(ret, '.$')
    let ret = ret[: -1 - len(char)]
    let width -= strwidth(char)
  endwhile

  return width
endfunction"}}}
function! vimshell#util#strwidthpart_len_reverse(str, width) "{{{
  let ret = a:str
  let width = strwidth(a:str)
  while width > a:width
    let char = matchstr(ret, '^.')
    let ret = ret[len(char) :]
    let width -= strwidth(char)
  endwhile

  return width
endfunction"}}}

function! s:buflisted(bufnr) "{{{
  return exists('t:tabpagebuffer') ?
        \ has_key(t:tabpagebuffer, a:bufnr) && buflisted(a:bufnr) :
        \ buflisted(a:bufnr)
endfunction"}}}

function! vimshell#util#expand(path) "{{{
  return s:get_prelude().substitute_path_separator(
        \ (a:path =~ '^\~') ? substitute(a:path, '^\~', expand('~'), '') :
        \ (a:path =~ '^\$\h\w*') ? substitute(a:path,
        \               '^\$\h\w*', '\=eval(submatch(0))', '') :
        \ a:path)
endfunction"}}}
function! vimshell#util#set_default(var, val, ...) "{{{
  if !exists(a:var) || type({a:var}) != type(a:val)
    let alternate_var = get(a:000, 0, '')

    let {a:var} = exists(alternate_var) ?
          \ {alternate_var} : a:val
  endif

  return {a:var}
endfunction"}}}
function! vimshell#util#set_default_dictionary_helper(variable, keys, value) "{{{
  for key in split(a:keys, '\s*,\s*')
    if !has_key(a:variable, key)
      let a:variable[key] = a:value
    endif
  endfor
endfunction"}}}
function! vimshell#util#set_dictionary_helper(variable, keys, value) "{{{
  for key in split(a:keys, '\s*,\s*')
    let a:variable[key] = a:value
  endfor
endfunction"}}}

function! vimshell#util#substitute_path_separator(...) "{{{
  return call(s:get_prelude().substitute_path_separator, a:000)
endfunction"}}}
function! vimshell#util#is_windows(...) "{{{
  return call(s:get_prelude().is_windows, a:000)
endfunction"}}}
function! vimshell#util#escape_file_searching(...) "{{{
  return call(s:get_prelude().escape_file_searching, a:000)
endfunction"}}}
function! vimshell#util#sort_by(...) "{{{
  return call(s:get_list().sort_by, a:000)
endfunction"}}}
function! vimshell#util#uniq(...) "{{{
  return call(s:get_list().uniq, a:000)
endfunction"}}}
function! vimshell#util#uniq_by(...) "{{{
  return call(s:get_list().uniq_by, a:000)
endfunction"}}}

function! vimshell#util#has_vimproc(...) "{{{
  return call(s:get_process().has_vimproc, a:000)
endfunction"}}}

function! vimshell#util#input_yesno(message) "{{{
  let yesno = input(a:message . ' [yes/no]: ')
  while yesno !~? '^\%(y\%[es]\|n\%[o]\)$'
    redraw
    if yesno == ''
      echo 'Canceled.'
      break
    endif

    " Retry.
    call vimshell#echo_error('Invalid input.')
    let yesno = input(a:message . ' [yes/no]: ')
  endwhile

  return yesno =~? 'y\%[es]'
endfunction"}}}

function! vimshell#util#is_cmdwin() "{{{
  return bufname('%') ==# '[Command Line]'
endfunction"}}}

function! vimshell#util#is_auto_select() "{{{
  return get(g:, 'neocomplcache_enable_auto_select', 0)
        \ || get(g:, 'neocomplete#enable_auto_select', 0)
        \ || &completeopt =~# 'noinsert'
endfunction"}}}

function! vimshell#util#is_complete_hold() "{{{
  return (get(g:, 'neocomplcache_enable_cursor_hold_i', 0)
        \ && !get(g:, 'neocomplcache_enable_insert_char_pre', 0)) ||
        \ get(g:, 'neocomplete#enable_cursor_hold_i', 0)
endfunction"}}}

function! vimshell#util#is_auto_delimiter() "{{{
  return get(g:, 'neocomplcache_enable_auto_delimiter', 0) ||
        \ get(g:, 'neocomplete#enable_auto_delimiter', 0)
endfunction"}}}

" Sudo check.
function! vimshell#util#is_sudo() "{{{
  return $SUDO_USER != '' && $USER !=# $SUDO_USER
      \ && $HOME !=# expand('~'.$USER)
      \ && $HOME ==# expand('~'.$SUDO_USER)
endfunction"}}}

function! vimshell#util#path2project_directory(...)
  return call(s:get_prelude().path2project_directory, a:000)
endfunction

function! vimshell#util#enable_auto_complete() "{{{
  if exists(':NeoCompleteUnlock')
    NeoCompleteUnlock
  endif
  if exists(':NeoComplcacheUnLock')
    NeoComplcacheUnLock
  endif
endfunction"}}}
function! vimshell#util#disable_auto_complete() "{{{
  " Skip next auto completion.
  if exists(':NeoCompleteLock')
    NeoCompleteLock
  endif
  if exists(':NeoComplcacheLock')
    NeoComplcacheLock
  endif
endfunction"}}}

function! vimshell#util#alternate_buffer() "{{{
  if bufnr('%') != bufnr('#') && s:buflisted(bufnr('#'))
    buffer #
    return
  endif

  let listed_buffer = filter(range(1, bufnr('$')),
        \ "s:buflisted(v:val) || v:val == bufnr('%')")
  let current = index(listed_buffer, bufnr('%'))
  if current < 0 || len(listed_buffer) < 3
    enew
    return
  endif

  execute 'buffer' ((current < len(listed_buffer) / 2) ?
        \ listed_buffer[current+1] : listed_buffer[current-1])
endfunction"}}}
function! vimshell#util#delete_buffer(...) "{{{
  let bufnr = get(a:000, 0, bufnr('%'))
  call vimshell#util#alternate_buffer()
  execute 'silent bwipeout!' bufnr
endfunction"}}}
function! s:buflisted(bufnr) "{{{
  return exists('t:tabpagebuffer') ?
        \ has_key(t:tabpagebuffer, a:bufnr) && buflisted(a:bufnr) :
        \ buflisted(a:bufnr)
endfunction"}}}

function! vimshell#util#glob(pattern, ...) "{{{
  if a:pattern =~ "'"
    " Use glob('*').
    let cwd = getcwd()
    let base = vimshell#util#substitute_path_separator(
          \ fnamemodify(a:pattern, ':h'))
    try
      execute (haslocaldir() ? 'lcd' : 'cd') fnameescape(base)

      let files = map(split(vimshell#util#substitute_path_separator(
            \ glob('*')), '\n'), "base . '/' . v:val")
    finally
      execute (haslocaldir() ? 'lcd' : 'cd') fnameescape(cwd)
    endtry

    return files
  endif

  " let is_force_glob = get(a:000, 0, 0)
  let is_force_glob = get(a:000, 0, 1)

  if !is_force_glob && a:pattern =~ '^[^\\*]\+/\*'
        \ && vimshell#util#has_vimproc() && exists('*vimproc#readdir')
    return filter(vimproc#readdir(a:pattern[: -2]), 'v:val !~ "/\\.\\.\\?$"')
  else
    " Escape [.
    if vimshell#util#is_windows()
      let glob = substitute(a:pattern, '\[', '\\[[]', 'g')
    else
      let glob = escape(a:pattern, '[')
    endif

    return split(vimshell#util#substitute_path_separator(glob(glob)), '\n')
  endif
endfunction"}}}
function! vimshell#util#get_vimshell_winnr(buffer_name) "{{{
  for winnr in filter(range(1, winnr('$')),
        \ "getbufvar(winbufnr(v:val), '&filetype') ==# 'vimshell'")
    let buffer_context = get(getbufvar(
          \ winbufnr(winnr), 'vimshell'), 'context', {})
    if !empty(buffer_context) &&
          \ buffer_context.buffer_name ==# a:buffer_name
      return winnr
    endif
  endfor

  return -1
endfunction"}}}

function! vimshell#util#head_match(checkstr, headstr) "{{{
  return stridx(a:checkstr, a:headstr) == 0
endfunction"}}}
function! vimshell#util#tail_match(checkstr, tailstr) "{{{
  return a:tailstr == '' || a:checkstr ==# a:tailstr
        \|| a:checkstr[: -len(a:tailstr)-1] ==# a:tailstr
endfunction"}}}
function! vimshell#util#resolve(filename) "{{{
  return ((vimshell#util#is_windows() && fnamemodify(a:filename, ':e') ==? 'LNK')
        \  || getftype(a:filename) ==# 'link') ?
        \ substitute(resolve(a:filename), '\\', '/', 'g') : a:filename
endfunction"}}}
function! vimshell#util#escape_match(str) "{{{
  return escape(a:str, '~" \.^$[]')
endfunction"}}}
function! vimshell#util#system(...) "{{{
  return call(s:get_process().system, a:000)
endfunction"}}}
function! vimshell#util#set_variables(variables) "{{{
  let variables_save = {}
  for [key, value] in items(a:variables)
    let save_value = exists(key) ? eval(key) : ''

    let variables_save[key] = save_value
    execute 'let' key '=' string(value)
  endfor

  return variables_save
endfunction"}}}
function! vimshell#util#restore_variables(variables) "{{{
  for [key, value] in items(a:variables)
    execute 'let' key '=' string(value)
  endfor
endfunction"}}}

" vim: foldmethod=marker
