"=============================================================================
" FILE: helper.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 17 Jul 2010
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

function! vimshell#complete#helper#files(cur_keyword_str, ...)"{{{
  " vimshell#complete#helper#files(cur_keyword_str [, path])

  if a:0 > 1
    echoerr 'Too many arguments.'
  endif

  " Not Filename pattern.
  if a:cur_keyword_str =~ 
        \'\*$\|\.\.\+$\|[/\\][/\\]\f*$\|[^[:print:]]\f*$\|/c\%[ygdrive/]$\|\\|$\|\a:[^/]*$'
    return []
  endif

  let l:cur_keyword_str = escape(a:cur_keyword_str, '[]')

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
    if vimshell#iswin()
      let l:env_ev = substitute(l:env_ev, '\\', '/', 'g')
    endif
    let l:len_env = len(l:env_ev)
  else
    let l:len_env = 0
    
    if a:cur_keyword_str =~ '^\~\h\w*'
      let l:cur_keyword_str = simplify($HOME . '/../' . l:cur_keyword_str[1:])
    endif
  endif
  
  try
    let l:glob = (a:0 == 1) ? globpath(a:1, l:cur_keyword_str . l:mask) : glob(l:cur_keyword_str . l:mask)
    let l:files = split(substitute(l:glob, '\\', '/', 'g'), '\n')
    
    if empty(l:files)
      " Add '*' to a delimiter.
      let l:cur_keyword_str = substitute(l:cur_keyword_str, '\w\+\ze[/._-]', '\0*', 'g')
      let l:glob = (a:0 == 1) ? globpath(a:1, l:cur_keyword_str . l:mask) : glob(l:cur_keyword_str . l:mask)
      let l:files = split(substitute(l:glob, '\\', '/', 'g'), '\n')
    endif
  catch
    call vimshell#echo_error(v:exception)
    return []
  endtry
  
  if empty(l:files)
    return []
  elseif len(l:files) > g:vimshell_max_list
    " Trunk items.
    let l:files = l:files[: g:vimshell_max_list - 1]
  endif

  let l:list = []
  let l:home_pattern = '^'.substitute($HOME, '\\', '/', 'g').'/'
  let l:paths = map((a:0 == 1 ? split(&path, ',') : [ getcwd() ]), 'substitute(v:val, "\\\\", "/", "g")')
  for word in l:files
    let l:dict = {
          \'word' : word, 'menu' : 'file'
          \}

    if l:len_env != 0 && l:dict.word[: l:len_env-1] == l:env_ev
      let l:dict.word = l:env . l:dict.word[l:len_env :]
    elseif a:cur_keyword_str =~ '^\~/'
      let l:dict.word = substitute(word, l:home_pattern, '\~/', '')
    elseif a:cur_keyword_str !~ '^\.\.\?/'
      " Path search.
      for path in l:paths
        if path != '' && vimshell#head_match(word, path . '/')
          let l:dict.word = l:dict.word[len(path)+1 : ]
          break
        endif
      endfor
    endif

    call add(l:list, l:dict)
  endfor

  let l:exts = escape(substitute($PATHEXT, ';', '\\|', 'g'), '.')
  for keyword in l:list
    let l:abbr = keyword.word

    if isdirectory(keyword.word)
      let l:abbr .= '/'
      let keyword.menu = 'directory'
    elseif vimshell#iswin()
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
        \ 'isdirectory(expand(v:val.orig)) || (vimshell#iswin() && fnamemodify(v:val.orig, ":e") ==? "LNK" && isdirectory(resolve(expand(v:val.orig))))')
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
        \ 'isdirectory(expand(v:val.orig)) || (vimshell#iswin() && fnamemodify(expand(v:val.orig), ":e") ==? "LNK" && isdirectory(resolve(expand(v:val.orig))))')
    if !has_key(l:check, keyword.word) && keyword.word =~ '/'
      let l:check[keyword.word] = keyword
    endif
  endfor

  let l:ret = []
  for keyword in values(l:check)
    let l:dict = l:keyword
    let l:dict.menu = 'cdpath'

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
function! vimshell#complete#helper#internals(cur_keyword_str)"{{{
  let l:commands = vimshell#available_commands()
  let l:ret = []
  for keyword in vimshell#complete#helper#keyword_simple_filter(keys(l:commands), a:cur_keyword_str)
    let l:dict = { 'word' : keyword, 'menu' : l:commands[keyword].kind }
    call add(l:ret, l:dict)
  endfor 

  return l:ret
endfunction"}}}
function! vimshell#complete#helper#executables(cur_keyword_str, ...)"{{{
  if a:cur_keyword_str =~ '[/\\]'
    let l:files = vimshell#complete#helper#files(a:cur_keyword_str)
  else
    let l:path = a:0 > 1 ? a:1 : vimshell#iswin() ? substitute($PATH, '\\\?;', ',', 'g') : substitute($PATH, '/\?:', ',', 'g')
    let l:files = vimshell#complete#helper#files(a:cur_keyword_str, l:path)
  endif
  
  if vimshell#iswin()
    let l:exts = escape(substitute($PATHEXT, ';', '\\|', 'g'), '.')
    let l:pattern = (a:cur_keyword_str =~ '[/\\]')? 
          \ 'isdirectory(expand(v:val.orig)) || "." . fnamemodify(v:val.orig, ":e") =~? '.string(l:exts) :
          \ '"." . fnamemodify(v:val.orig, ":e") =~? '.string(l:exts)
  else
    let l:pattern = (a:cur_keyword_str =~ '[/\\]')? 
          \ 'isdirectory(expand(v:val.orig)) || executable(expand(v:val.orig))' : 'executable(expand(v:val.orig))'
  endif

  call filter(l:files, l:pattern)

  let l:ret = []
  for keyword in l:files
    let l:dict = l:keyword
    let l:dict.menu = 'command'
    if a:cur_keyword_str !~ '[/\\]'
      let l:dict.word = vimshell#iswin() ? 
            \ fnamemodify(l:keyword.word, ':t:r') : fnamemodify(l:keyword.word, ':t')
      let l:dict.abbr = vimshell#iswin() ? 
            \ fnamemodify(l:keyword.abbr, ':t:r') . '*' : fnamemodify(l:keyword.abbr, ':t')
    endif

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
    return vimshell#complete#helper#executables(a:args[0])
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
  if a:cur_keyword_str == ''
    return a:list
  endif
  
  let l:cur_keyword = substitute(a:cur_keyword_str, '\\\zs.', '\0', 'g')

  return filter(a:list, printf("v:val[: %d] == %s", len(l:cur_keyword) - 1, string(l:cur_keyword)))
endfunction"}}}

" vim: foldmethod=marker
