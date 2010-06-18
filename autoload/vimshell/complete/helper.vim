"=============================================================================
" FILE: helper.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 18 Jun 2010
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

" cur_keyword_str [, path]
function! vimshell#complete#helper#files(cur_keyword_str, ...)"{{{
  if a:0 > 1
    echoerr 'Too many arguments.'
  endif

  " Not Filename pattern.
  if a:cur_keyword_str =~ 
        \'\*$\|\.\.\+$\|[/\\][/\\]\f*$\|[^[:print:]]\f*$\|/c\%[ygdrive/]$\|\\|$\|\a:[^/]*$'
    return []
  endif

  let l:cur_keyword_str = escape(a:cur_keyword_str, '[]')

  let l:is_win = has('win32') || has('win64')
  let l:cur_keyword_str = substitute(l:cur_keyword_str, '\\ ', ' ', 'g')

  " Set mask.
  if l:cur_keyword_str =~ '\*$'
    let l:mask = ''
  else
    let l:mask = '*'
  endif

  if a:cur_keyword_str =~ '^\$\h\w*'
    let l:env = matchstr(a:cur_keyword_str, '^\$\h\w*')
    let l:env_ev = eval(l:env)
    if l:is_win
      let l:env_ev = substitute(l:env_ev, '\\', '/', 'g')
    endif
    let l:len_env = len(l:env_ev)
  else
    let l:len_env = 0
  endif

  try
    let l:glob = (a:0 == 1) ? globpath(a:1, l:cur_keyword_str . l:mask) : glob(l:cur_keyword_str . l:mask)
    let l:files = split(substitute(l:glob, '\\', '/', 'g'), '\n')
    
    if empty(l:files)
      " Add '*' to a delimiter.
      let l:cur_keyword_str = substitute(l:cur_keyword_str, '\w\+\ze[/._-]', '\0*', 'g')
      let l:glob = (a:0 == 1) ? glob(l:cur_keyword_str . l:mask) : globpath(a:1, l:cur_keyword_str . l:mask)
      let l:files = split(substitute(glob(l:glob), '\\', '/', 'g'), '\n')
    endif
  catch
    return []
  endtry
  
  if empty(l:files) || 
    return []
  elseif len(l:files) > g:vimshell_max_list
    " Trunk items.
    let l:files = l:files[: g:neocomplcache_max_list - 1]
  endif

  let l:list = []
  let l:home_pattern = '^'.substitute($HOME, '\\', '/', 'g').'/'
  for word in l:files
    let l:dict = {
          \'word' : substitute(word, l:home_pattern, '\~/', ''), 'menu' : 'file'
          \}

    if l:len_env != 0 && l:dict.word[: l:len_env-1] == l:env_ev
      let l:dict.word = l:env . l:dict.word[l:len_env :]
    endif

    call add(l:list, l:dict)
  endfor

  let l:exts = escape(substitute($PATHEXT, ';', '\\|', 'g'), '.')
  for keyword in l:list
    let l:abbr = keyword.word

    if isdirectory(keyword.word)
      let l:abbr .= '/'
      let keyword.menu = 'directory'
    elseif l:is_win
      if '.'.fnamemodify(keyword.word, ':e') =~ l:exts
        let l:abbr .= '*'
        let keyword.menu = 'executable'
      endif
    elseif executable(keyword.word)
      let l:abbr .= '*'
      let keyword.menu = 'executable'
    endif

    let keyword.abbr = l:abbr

    " Escape word.
    let keyword.orig = keyword.word
    let keyword.word = escape(keyword.word, ' *?[]"={}')
  endfor

  return l:list
endfunction"}}}
function! vimshell#complete#helper#directories(cur_keyword_str)"{{{
  let l:ret = []
  for keyword in filter(vimshell#complete#helper#files(a:cur_keyword_str), 
        \ 'isdirectory(v:val.orig) || (vimshell#iswin() && fnamemodify(v:val.orig, ":e") ==? "LNK" && isdirectory(resolve(v:val.orig)))')
    let l:dict = l:keyword
    let l:dict.menu = 'directory'

    call add(l:ret, l:dict)
  endfor

  return l:ret
endfunction"}}}
function! vimshell#complete#helper#cdpath_directories(cur_keyword_str)"{{{
  " Check dup.
  let l:check = {}
  for keyword in filter(vimshell#complete#helper#files(a:cur_keyword_str, &cdpath), 
        \ 'isdirectory(v:val.orig) || (vimshell#iswin() && fnamemodify(v:val.orig, ":e") ==? "LNK" && isdirectory(resolve(v:val.orig)))')
    if !has_key(l:check, keyword) && keyword =~ '/'
      let l:check[keyword] = keyword
    endif
  endfor

  let l:ret = []
  let l:home_pattern = '^'.substitute($HOME, '\\', '/', 'g').'/'
  for keyword in keys(l:check)
    " Substitute home path.
    let keyword = substitute(keyword, l:home_pattern, '\~/', '')
    let l:dict = l:keyword
    let l:dict.menu = 'directory'

    call add(l:ret, l:dict)
  endfor

  return l:ret
endfunction"}}}
function! vimshell#complete#helper#directory_stack(cur_keyword_str)"{{{
  let l:ret = []

  for keyword in vimshell#complete#helper#keyword_simple_filter(range(len(b:vimshell.directory_stack)), a:cur_keyword_str)
    let l:dict = { 'word' : keyword, 'menu' : b:vimshell.directory_stack[keyword] }

    call add(l:ret, l:dict)
  endfor 

  return l:ret
endfunction"}}}
function! vimshell#complete#helper#aliases(cur_keyword_str)"{{{
  let l:ret = []
  for keyword in vimshell#complete#helper#keyword_simple_filter(keys(b:vimshell.alias_table), a:cur_keyword_str)
    let l:dict = { 'word' : keyword }

    if len(b:vimshell.alias_table[keyword]) > 15
      let l:dict.menu = 'alias ' . printf("%s..%s", b:vimshell.alias_table[keyword][:8], b:vimshell.alias_table[keyword][-4:])
    else
      let l:dict.menu = 'alias ' . b:vimshell.alias_table[keyword]
    endif

    call add(l:ret, l:dict)
  endfor 

  return l:ret
endfunction"}}}
function! vimshell#complete#helper#specials(cur_keyword_str)"{{{
  let l:ret = []
  for keyword in vimshell#complete#helper#keyword_simple_filter(keys(g:vimshell#special_func_table), a:cur_keyword_str)
    let l:dict = { 'word' : keyword, 'menu' : 'special' }
    call add(l:ret, l:dict)
  endfor 

  return l:ret
endfunction"}}}
function! vimshell#complete#helper#internals(cur_keyword_str)"{{{
  let l:ret = []
  for keyword in vimshell#complete#helper#keyword_simple_filter(keys(g:vimshell#internal_func_table), a:cur_keyword_str)
    let l:dict = { 'word' : keyword, 'menu' : 'internal' }
    call add(l:ret, l:dict)
  endfor 

  return l:ret
endfunction"}}}
function! vimshell#complete#helper#commands(cur_keyword_str)"{{{
  let l:ret = []

  let l:pattern = printf('[/~]\?\f\+[%s]\f*$', l:PATH_SEPARATOR)
  if vimshell#iswin()
    let l:path = substitute($PATH, '\\\?;', ',', 'g')
    let l:exts = escape(substitute($PATHEXT, ';', '\\|', 'g'), '.')

    let l:files = a:cur_keyword_str =~ l:pattern ? glob(a:cur_keyword_str . '*') : globpath(l:path, a:cur_keyword_str . '*')
    let l:list = map(filter(split(l:files, '\n'),
          \'"." . fnamemodify(v:val, ":e") =~ '.string(l:exts)), 'fnamemodify(v:val, ":t:r")')
  else
    let l:path = substitute($PATH, '/\?:', ',', 'g')

    let l:files = a:cur_keyword_str =~ l:pattern ? glob(a:cur_keyword_str . '*') : globpath(l:path, a:cur_keyword_str . '*')
    let l:list = map(filter(split(globpath(l:path, a:cur_keyword_str . '*'), '\n'),
          \'executable(v:val)'), 'fnamemodify(v:val, ":t:r")')
  endif

  for keyword in l:list
    let l:dict = { 'word' : keyword, 'abbr' : keyword.'*', 'menu' : 'command' }
    call add(l:ret, l:dict)
  endfor 

  return l:ret
endfunction"}}}
function! vimshell#complete#helper#buffers(cur_keyword_str)"{{{
  let l:ret = []
  let l:bufnumber = 1
  while l:bufnumber <= bufnr('$')
    if buflisted(l:bufnumber) && vimshell#head_match(bufname(l:bufnumber), a:cur_keyword_str)
      let l:keyword = bufname(l:bufnumber)
      let l:dict = { 'word' : escape(keyword, ' *?[]"={}'), 'menu' : 'buffer' }
      call add(l:ret, l:dict)
    endif

    let l:bufnumber += 1
  endwhile

  return l:ret
endfunction"}}}
function! vimshell#complete#helper#command_args(args)"{{{
  " command args...
  if len(a:args) == 1
    " Commands.
    return vimshell#complete#helper#commands(a:args[0])
  else
    " Args.
    return vimshell#complete#args_complete#get_complete_words(a:args[0], a:args[1:])
  endif
endfunction"}}}

function! vimshell#complete#helper#compare_rank(i1, i2)"{{{
  return a:i1.rank < a:i2.rank ? 1 : a:i1.rank == a:i2.rank ? 0 : -1
endfunction"}}}
function! vimshell#complete#helper#keyword_filter(list, cur_keyword_str)"{{{
  let l:cur_keyword = substitute(a:cur_keyword_str, '\\\zs.', '\0', 'g')

  return filter(a:list, printf("v:val[: %d] == %s", len(l:cur_keyword) - 1, string(l:cur_keyword)))
endfunction"}}}
function! vimshell#complete#helper#keyword_simple_filter(list, cur_keyword_str)"{{{
  let l:cur_keyword = substitute(a:cur_keyword_str, '\\\zs.', '\0', 'g')

  return filter(a:list, printf("v:val[: %d] == %s", len(l:cur_keyword) - 1, string(l:cur_keyword)))
endfunction"}}}

" vim: foldmethod=marker
